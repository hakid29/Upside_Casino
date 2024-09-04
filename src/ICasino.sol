// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ICasino {
    enum State {
        Ready,
        BetAndReveal,
        End
    }

    struct Game {
        State state;
        address creator;
        bool draw;
        uint256 totalBettor;
        uint256 totalBetBalance;
        uint256 answer;
        uint256 startBlock;
        uint256 bettingTerm;
        uint256 revealTerm;
        ERC20 token;
    }

    struct Bettor {
        uint256 guess;
        uint256 betAmount;
        bool isWinner;
        uint256 commit;
        bool revealed;
    }

    function ADMIN() external view returns (address);

    function gameCount() external view returns (uint256);

    function gameFee() external view returns (uint256);

    function games(uint256 gameId) external view returns (Game memory);

    function Bettors(uint256 gameId, address user) external view returns (Bettor memory);

    function EachGuessAmount(uint256 gameId, uint256 guess) external view returns (uint256);

    function initialize(address initialOwner) external;

    function create(address token_, uint256 bettingTerm_, uint256 revealTerm_) external returns (uint256);

    function start(uint256 gameId) external;

    function bet(uint256 gameId, uint256 amount, uint256 guess_, uint256 commit_) external payable;

    function reveal(uint256 gameId, uint256 commit_) external;

    function draw(uint256 gameId) external;

    function claim(uint256 gameId) external;

    function multicall(bytes[] calldata calls) external returns (bytes[] memory results);
}
