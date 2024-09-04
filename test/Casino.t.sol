// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {Casino} from "../src/Casino.sol";
import {MyProxy} from "../src/Proxy.sol";
import {ICasino} from "../src/ICasino.sol";

contract CUBC is ERC20 {
    constructor() ERC20("Bet Coin", "BC") {
        _mint(msg.sender, type(uint256).max);
    }
}

contract CasinoTest is Test {
    Casino casino;
    MyProxy proxy;
    ERC20 bc;
    ICasino proxyForTest;

    address creator;
    address[10] users;
    address user1;

    address ADMIN = 0xDa980361A953c52bBd4a057310771b98C01a51d4;

    function setUp() public {
        casino = new Casino();
        proxy = new MyProxy(address(casino), abi.encodeWithSignature("initialize(address)", ADMIN));
        proxyForTest = ICasino(address(proxy));
        bc = new CUBC();

        creator = address(0x10);
        for(uint i = 0; i < 10; i++) {
            users[i] = address(uint160(0x11 + i));
            bc.transfer(users[i], 1000 ether);
        }
        bc.transfer(address(proxy), 10000 ether);

        user1 = users[0];
    }

    function testAdminTryToUpgrade() public {
        Casino casino2 = new Casino();

        vm.startPrank(ADMIN);
        (bool success,) = address(proxy).call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(casino2), ""));
        require(success);
        vm.stopPrank();
    }

    function testNotAdminTryToUpgrade() public {
        Casino casino2 = new Casino();

        vm.expectRevert();
        vm.startPrank(address(this));
        (bool success,) = address(proxy).call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(casino2), ""));
        require(success);
        vm.stopPrank();
    }

    function testCreateAndStart() public {
        vm.startPrank(creator);

        uint256 myGameId = proxyForTest.create(address(bc), 300, 100);
        assertEq(myGameId == 0, true); // first gameId is 0

        vm.stopPrank();
    }

    function testBetTokenAmount() public {
        vm.startPrank(creator);

        uint256 myGameId = proxyForTest.create(address(bc), 300, 100);
        proxyForTest.start(myGameId);

        vm.stopPrank();

        vm.startPrank(user1);

        // valid allowance
        bc.approve(address(proxy), 1 ether);
        proxyForTest.bet(myGameId, 1 ether, 1, 123456789);

        vm.stopPrank();
    }

    function testDraw() public {
        vm.startPrank(creator);

        uint256 myGameId = proxyForTest.create(address(bc), 300, 100);
        proxyForTest.start(myGameId);

        vm.stopPrank();


        vm.startPrank(user1);
        uint256 user1Commit = 123456789;
        bc.approve(address(proxy), 1 ether);
        proxyForTest.bet(myGameId, 1 ether, 1, user1Commit);

        vm.roll(block.number + 150);

        vm.expectRevert("now is not reveal term");
        proxyForTest.reveal(myGameId, user1Commit);

        vm.roll(block.number + 150);

        proxyForTest.reveal(myGameId, user1Commit);

        vm.roll(block.number + 100);

        proxyForTest.draw(myGameId);

        vm.stopPrank();

        vm.expectRevert();
        proxyForTest.draw(myGameId); // try double draw
    }

    function testMulticall1() public {
        vm.startPrank(creator);

        bytes[] memory multicall_ = new bytes[](2);

        multicall_[0] = abi.encodeWithSignature("create(address,uint256,uint256)", address(bc), 100, 30);   
        // console.log("address : ", )
        multicall_[1] = abi.encodeWithSignature("start(uint256)", 0);

        proxyForTest.multicall(multicall_);
        vm.stopPrank();
    }

    function testMulticall2() public {
        vm.startPrank(creator);

        bytes[] memory multicall_ = new bytes[](2);

        multicall_[0] = abi.encodeWithSignature("create(address,uint256,uint256)", address(bc), 100, 30);   
        // console.log("address : ", )
        multicall_[1] = abi.encodeWithSignature("start(uint256)", 0);

        proxyForTest.multicall(multicall_);
        vm.stopPrank();


        address creator2 = address(0x21);
        vm.startPrank(creator2);

        bytes[] memory multicall2_ = new bytes[](2);

        multicall2_[0] = abi.encodeWithSignature("create(address,uint256,uint256)", address(bc), 100, 30);   
        // console.log("address : ", )
        multicall2_[1] = abi.encodeWithSignature("start(uint256)", 1);

        proxyForTest.multicall(multicall2_);
        vm.stopPrank();


        vm.startPrank(user1);
        bc.approve(address(proxy), 2 ether);

        bytes[] memory multicall3_ = new bytes[](2);

        // bet to creator's game
        multicall3_[0] = abi.encodeWithSignature("bet(uint256,uint256,uint256,uint256)", 0, 1 ether, 1, 123456789);   
        // bet to creator2's game
        multicall3_[1] = abi.encodeWithSignature("bet(uint256,uint256,uint256,uint256)", 1, 1 ether, 2, 987654321);   

        proxyForTest.multicall(multicall3_);
        vm.stopPrank();
    }

    function testAll() public {
        vm.startPrank(creator);

        uint256 myGameId = proxyForTest.create(address(bc), 300, 100);
        proxyForTest.start(myGameId);

        vm.stopPrank();

        // each user bets 1~10 (there is 1 winner)
        for (uint i = 0; i < 10; i++) {
            vm.startPrank(users[i]);

            uint256 userCommit = 123456789 + i;
            bc.approve(address(proxy), 1 ether);
            proxyForTest.bet(myGameId, 1 ether, i+1, userCommit);

            vm.stopPrank();
        }

        vm.roll(block.number + 300);

        vm.startPrank(ADMIN);
        proxyForTest.pause();
        vm.stopPrank();

        vm.roll(block.number + 300);

        vm.startPrank(ADMIN);
        proxyForTest.unpause();
        vm.stopPrank();
        // each user reveals
        for (uint i = 0; i < 10; i++) {
            vm.startPrank(users[i]);

            uint256 userCommit = 123456789 + i;
            proxyForTest.reveal(myGameId, userCommit);

            vm.stopPrank();
        }

        vm.roll(block.number + 100);

        proxyForTest.draw(myGameId);
        uint256 answer = proxyForTest.games(myGameId).answer;
        address winner = users[answer - 1];

        console.log("before claim : ", bc.balanceOf(winner));
        // each user claims
        for (uint i = 0; i < 10; i++) {
            vm.startPrank(users[i]);

            proxyForTest.claim(myGameId);

            vm.stopPrank();
        }

        console.log("after claim : ", bc.balanceOf(winner));
        
        // Winner
        uint256 winnerBetAmount = proxyForTest.Bettors(myGameId, winner).betAmount;
        uint256 gameTotalBetBalance = proxyForTest.games(myGameId).totalBetBalance;
        vm.assertEq(bc.balanceOf(winner), 1000*1e18 - winnerBetAmount + gameTotalBetBalance * (1000 - proxyForTest.gameFee()) / 1000);

        // Losers
        for (uint i = 0; i < 10; i++) {
            if (i != answer - 1) {
                vm.assertEq(bc.balanceOf(users[i]), 1000*1e18 - proxyForTest.Bettors(myGameId, users[i]).betAmount);
            }
        }
    }
}
