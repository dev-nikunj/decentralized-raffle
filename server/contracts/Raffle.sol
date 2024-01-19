// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/*imports */
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

/*errors*/
error Raffle__NotEnoughETHEntered();
error Raffle__NoPlayersInTheContest();
error Raffle__WinnerTransactionFailed();
error Raffle__OwnerTransactionFailed();
error Raffle__UpkeepNotNeeded(
    uint256 currentBalance,
    uint256 numPlayers,
    uint256 rafflePlayers
);

/*contract*/
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /*
    -user entering the contsest
    -pick a random user as winner using random number from chainlink oracle 
    -selecting winner at every fixed time period 
    */

    /* Types   */
    enum RaffleState {
        OPEN,
        CALCULATING,
        CLOSED
    }

    /*state vars */
    uint256 private immutable i_enteranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    address private immutable i_owner;

    /*lottery vars */
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimestamp;
    uint256 private immutable i_interval;

    /*events */
    event RaffleEnter(address indexed player);
    event ReqestedRaffleWinner(uint256 indexed requestId);

    /*constructor */
    constructor(
        address vrfCoordinatorV2, //contract
        uint256 enteranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_owner = msg.sender;
        i_enteranceFee = enteranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimestamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() public payable {
        // if (msg.value < i_enteranceFee) {
        //     revert Raffle__NotEnoughETHEntered();
        // }

        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev following function uses chainlink keepers functionality to do computation off chain ,
     * the chainlink keepers node calls this function and looks for true
     *
     */

    function checkUpkeep(
        bytes memory /*checkData */
    )
        public
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimestamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalanace = (address(this).balance > 0);
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalanace);
    }

    function performUpkeep(bytes calldata /*performData */) external override {
        //request random number
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //gasLane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit ReqestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_lastTimestamp = block.timestamp;

        if (s_players.length < 1) {
            revert Raffle__NoPlayersInTheContest();
        }

        //send the funds to lottery winner
        uint256 contractBalance = address(this).balance;
        uint256 winnerShare = (contractBalance * 80) / 100;
        uint256 ownerShare = contractBalance - winnerShare;

        //sending 80% to winner
        (bool winnerSuccess, ) = recentWinner.call{value: winnerShare}("");
        if (!winnerSuccess) {
            revert Raffle__WinnerTransactionFailed();
        }

        //sending remainings to owner
        (bool ownerSuccess, ) = recentWinner.call{value: ownerShare}("");
        if (!ownerSuccess) {
            revert Raffle__OwnerTransactionFailed();
        }
    }

    /*get pure/view function */
    function getEntranceFee() public view returns (uint256) {
        return i_enteranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
