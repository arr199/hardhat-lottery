// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

error Lottery__NotEnoughEthEntered();
error NotOwner();
error Raffle__WinnerTransferFailed();
error Raffle__CalculatingWinner();

abstract contract Lottery is VRFConsumerBaseV2, AutomationCompatibleInterface {
    // Type declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // Variables
    uint256 private immutable i_entranceFee;
    address payable[] private players;
    address owner;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //  Lotery variables
    address payable private recentWinner;
    RaffleState private raffleState;

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender == owner) {
            revert NotOwner();
            _;
        }
    }

    // Events
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleRecentWinner(address indexed recentWinner);

    // Constructor
    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        owner = msg.sender;
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        raffleState = RaffleState.OPEN;
    }

    // Functions
    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Lottery__NotEnoughEthEntered();
        }
        if (raffleState != RaffleState.OPEN) {
            revert Raffle__CalculatingWinner();
        }

        players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev this is the function that chainlink-automation is going to call
     * they look for the upkeepNeeded in order to return true
     * 1. Our time interval should have passed
     * 2. The contract should have some ETH and at least 1 player
     * 3. Our subcription is funded with some Link
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.

        
    }

    function requestRandomWinner() external {
        raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        uint256 winnerIndex = randomWords[0] % players.length;
        recentWinner = players[winnerIndex];

        players = new address payable[](0);
        raffleState = RaffleState.OPEN;

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__WinnerTransferFailed();
        }

        emit RaffleRecentWinner(recentWinner);
    }

    //  Pure / View functions
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return players[index];
    }
}
