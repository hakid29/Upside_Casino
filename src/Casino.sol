// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract Casino is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    enum State {
        Ready,      // before game start
        Running,    // running game
        Commit,     // commit time
        End         // after game runs
    }

    struct Game {
        State state;
        address creator;
        bool draw; // whether the game has drawed, if it has drawed, it can be End state
        uint256 totalBettor;
        uint256 totalBetBalance;
        uint256 answer;
        uint256 startBlock;
        uint256 runningTerm;
        ERC20 token;
    }

    struct Bettor {
        uint256 guess;
        uint256 betAmount;
        uint256 isWinner;
    }

    address public constant ADMIN = 0xDa980361A953c52bBd4a057310771b98C01a51d4;
    uint256 public gameCount;
    uint256 public gameFee = 2; // 2% fee
    ERC20 public token;

    mapping(uint256 => Game) public games; // gameId => State
    mapping(uint256 => mapping(uint256 => address)) public matchBettor;
    mapping(uint256 => mapping(address => Bettor)) public Bettors;

    event logStart(uint);

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    modifier isReady(uint256 gameId){
        require(games[gameId].state == State.Ready);
        _;
    }

    modifier isRunning(uint256 gameId){
        require(games[gameId].state == State.Running);
        _;
    }

    modifier isEnd(uint256 gameId){
        require(games[gameId].state == State.End);
        _;
    }

    function create(address token_, uint256 runningTerm_) public returns(uint256) {
        Game memory newGame;

        newGame.state = State.Ready;
        newGame.runningTerm = runningTerm_;
        newGame.creator = msg.sender;
        newGame.token = ERC20(token_);

        games[gameCount] = newGame;
        gameCount++;
        return gameCount-1; // gameId
    }

    function start(uint256 gameId) public isReady(gameId) {
        require(msg.sender == games[gameId].creator, "only creator of the game can start");

        games[gameId].state = State.Running;
        games[gameId].startBlock = block.number;
        emit logStart(gameId);
    }

    function bet(uint256 gameId, address token_, uint256 amount, uint256 guess_) public isRunning(gameId) payable {
        require(games[gameId].creator != address(0), "game doesn't exist");
        require(games[gameId].token == ERC20(token_), "wrong token");
        require(amount > 0 && amount < ERC20(token_).balanceOf(address(this)), "Invalid amount");
        // Check
        require(ERC20(token_).allowance(msg.sender, address(this)) >= amount, "Invalid allowance");
        require(Bettors[gameId][msg.sender].betAmount == 0, "you can bet only once");

        // Effect
        matchBettor[gameId][games[gameId].totalBettor] = msg.sender; // userId in game
        Bettors[gameId][msg.sender].betAmount = amount;
        Bettors[gameId][msg.sender].guess = guess_;
        games[gameId].totalBetBalance += amount;

        // Interact
        ERC20(token_).transferFrom(msg.sender, address(this), amount);
    }

    function draw(uint256 gameId) public returns(uint256) {
        require(msg.sender == ADMIN, "you are not admin");
        require(block.number - games[gameId].startBlock >= games[gameId].runningTerm, "bet isn't finished");


    }

    function claim(uint256 gameId) public isEnd(gameId) {

    }

    function multicall(
        bytes[] calldata calls
    ) external virtual returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);

            require(success, "Call failed!");
            results[i] = result;
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}

// forge create --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d src/Casino.sol:Casino
