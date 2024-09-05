// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract Casino is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    enum State {
        Ready,           // before game start
        Running,         // betting or reveal time
        End              // after reveal
    }

    struct Game {
        State state;
        address creator;
        uint256 totalBetBalance;
        uint256 answer;
        uint256 startBlock;
        uint256 bettingTerm;  // betting time
        uint256 revealTerm;   // reveal time
        ERC20 token;
    }

    struct Bettor {
        uint256 guess;
        uint256 betAmount;
        bool isWinner;
        uint256 commit;
        bool revealed;
    }

    uint256 public gameCount;
    uint256 public constant gameFee = 1; // 0.1% fee
    uint256 public lastPause;

    mapping(uint256 => Game) public Games;                                  // gameId => State
    mapping(uint256 => mapping(address => Bettor)) public Bettors;          // gameId => bettor's address => Bettor
    mapping(uint256 => mapping(uint256 => uint256)) public EachGuessAmount; // gameId => guess => totalAmount

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    modifier isReady(uint256 gameId){
        require(Games[gameId].state == State.Ready);
        _;
    }

    modifier isRunning(uint256 gameId){
        require(Games[gameId].state == State.Running);
        _;
    }

    modifier isEnd(uint256 gameId){
        require(Games[gameId].state == State.End);
        _;
    }

    function create(address token_, uint256 bettingTerm_, uint256 revealTerm_) public whenNotPaused returns(uint256) {
        Game memory newGame;

        newGame.state = State.Ready;
        newGame.bettingTerm = bettingTerm_;
        newGame.revealTerm = revealTerm_;
        newGame.creator = msg.sender;
        newGame.token = ERC20(token_);

        Games[gameCount] = newGame;
        gameCount++;
        return gameCount-1; // gameId
    }

    function start(uint256 gameId) public isReady(gameId) whenNotPaused {
        require(msg.sender == Games[gameId].creator, "only creator of the game can start");

        Games[gameId].state = State.Running;
        Games[gameId].startBlock = block.number;
    }

    function bet(uint256 gameId, uint256 amount, uint256 guess_, uint256 commit_) public isRunning(gameId) whenNotPaused {
        // block.number - startblock < (betting time)
        require(block.number - Games[gameId].startBlock < Games[gameId].bettingTerm, "now is not betting term");
        require(Games[gameId].creator != address(0), "game doesn't exist");

        ERC20 token_ = Games[gameId].token;

        // Check
        require(amount > 0, "Invalid amount");
        require(token_.allowance(msg.sender, address(this)) >= amount, "Invalid allowance");
        require(Bettors[gameId][msg.sender].betAmount == 0, "you can bet only once");

        // Effect
        Bettor memory bettor;
        bettor.betAmount = amount;
        bettor.guess = guess_;
        bettor.commit = commit_;
        Bettors[gameId][msg.sender] = bettor;

        Games[gameId].totalBetBalance += amount;

        EachGuessAmount[gameId][guess_] += amount;

        // Interact
        token_.transferFrom(msg.sender, address(this), amount);
    }

    function reveal(uint256 gameId, uint256 commit_) public isRunning(gameId) whenNotPaused {
        // (betting time) <= block.number - startblock <= (betting time) + (reveal time)
        require(block.number - Games[gameId].startBlock >= Games[gameId].bettingTerm
        && block.number - Games[gameId].startBlock < Games[gameId].bettingTerm + Games[gameId].revealTerm, "now is not reveal term");
        require(Bettors[gameId][msg.sender].commit == commit_, "wrong commit");

        Games[gameId].answer = uint256(keccak256(abi.encodePacked(Games[gameId].answer, commit_))); // reveal
        Bettors[gameId][msg.sender].revealed = true;
    }

    function draw(uint256 gameId) public isRunning(gameId) whenNotPaused {
        // block.number - startblock > (betting time) + (reveal time)
        require(block.number - Games[gameId].startBlock >= Games[gameId].bettingTerm + Games[gameId].revealTerm, "reveal isn't finished");
        require(Games[gameId].answer > 10, "already draw");

        uint256 answer_ = (Games[gameId].answer % 10) + 1;
        Games[gameId].answer = answer_; // guess >= 1
        Games[gameId].state = State.End;

        address creator_ = Games[gameId].creator;
        Games[gameId].token.transfer(creator_, Games[gameId].totalBetBalance * 2 / 10000); // 0.02% fee to creator
    }

    function claim(uint256 gameId) public isEnd(gameId) whenNotPaused {
        require(Bettors[gameId][msg.sender].guess != 0, "already claimed");
        Bettor memory bettor = Bettors[gameId][msg.sender];
        uint256 answer_;
        uint256 reward;

        if (bettor.revealed) { // those who didn't reveal can't claim
            if (bettor.guess == Games[gameId].answer) {

                answer_ = Games[gameId].answer;
                reward = Games[gameId].totalBetBalance * bettor.betAmount / EachGuessAmount[gameId][answer_];
                Games[gameId].token.transfer(msg.sender, reward * (1000 - gameFee) / 1000);
            } else if (Games[gameId].totalBetBalance == 0) {
                // if there is no winner
                Games[gameId].token.transfer(msg.sender, bettor.betAmount * (1000 - gameFee) / 1000);
            }
        } else {
            Games[gameId].token.transfer(msg.sender, bettor.betAmount * (1000 - 3*gameFee) / 1000);
        }

        Bettors[gameId][msg.sender].guess = 0; // prevent double claim
    }

    function multicall(
        bytes[] calldata calls
    ) external returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);

            require(success, "Call failed!");
            results[i] = result;
        }
    }

    function pause() external onlyOwner {
        _pause();
        lastPause = block.number;
    }

    function unpause() external onlyOwner {
        _unpause();
        uint256 pausedBlock = block.number - lastPause;

        // paused Block must be reflected to games
        for (uint i = 0; i < gameCount; i++) {
            Games[i].startBlock += pausedBlock;
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}
