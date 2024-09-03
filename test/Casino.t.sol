// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {Casino} from "../src/Casino.sol";
import {Proxy, ITransparentUpgradeableProxy} from "../src/proxy//Proxy.sol";
import {MyProxyAdmin} from "../src/proxy//ProxyAdmin.sol";

contract CUBC is ERC20 {
    constructor() ERC20("Bet Coin", "BC") {
        _mint(msg.sender, type(uint256).max);
    }
}

contract CasinoTest is Test {
    Casino casino;
    Proxy proxy;
    MyProxyAdmin proxyadmin;
    ERC20 bc;

    address creator;
    address user1;
    address user2;

    address ADMIN = 0xDa980361A953c52bBd4a057310771b98C01a51d4;

    function setUp() public {
        creator = address(0x11);
        user1 = address(0x12);
        user2 = address(0x13);

        casino = new Casino();
        proxy = new Proxy(address(casino), ADMIN, "");
        proxyadmin = new MyProxyAdmin(ADMIN);

        bc = new CUBC();
        bc.transfer(user1, 1000 ether);
        bc.transfer(user2, 2000 ether);
        bc.transfer(address(proxy), 10000 ether);
    }

    function testAdminTryToUpgrade() public {
        Casino casino2 = new Casino();

        vm.startPrank(ADMIN);
        proxyadmin.upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(casino2), "");
    }

    // function testNotAdminTryToUpgrade() public {
    //     vm.expectRevert();
    //     vm.startPrank(address(this));
    //     proxy.upgradeTo(address(casino));
    //     vm.stopPrank();
    //     console.log(block.timestamp);
    // }

    // function testCreateAndRun() public {
    //     vm.startPrank(creator);
    //     (bool success, bytes memory result) = address(proxy).call(abi.encodeWithSignature("create(address,uint256)", address(bc), 100));
    //     require(success, "game not created");
    //     uint256 myGameId = uint256(bytes32(result));

    //     assertEq(myGameId == 0, true);

    //     console.log(block.timestamp);
    // }

    // function testBetTokenAmount() public {
    //     vm.startPrank(creator);
    //     (bool success, bytes memory result) = address(proxy).call(abi.encodeWithSignature("create(address,uint256)", address(bc), 100));
    //     require(success, "game not created");
    //     uint256 myGameId = uint256(bytes32(result));

    //     (bool success2,) = address(proxy).call(abi.encodeWithSignature("start(uint256)", myGameId));
    //     require(success2, "game not started");
    //     vm.stopPrank();

    //     // invalid token
    //     vm.startPrank(user1);
    //     (bool success3,) = address(proxy).call(abi.encodeWithSignature("bet(uint256,address,uint256,uint256)", myGameId, address(0x100), 0, 0));
    //     require(success3 == false);

    //     // valid token
    //     bc.approve(address(proxy), 1 ether);
    //     (bool success4,) = address(proxy).call(abi.encodeWithSignature("bet(uint256,address,uint256,uint256)", myGameId, address(bc), 1 ether, 0));
    //     require(success4 == true);
    //     vm.stopPrank();
    // }

    // function testDraw() public {
    //     vm.startPrank(creator);
    //     (bool success, bytes memory result) = address(proxy).call(abi.encodeWithSignature("create(address,uint256)", address(bc), 100));
    //     require(success, "game not created");
    //     uint256 myGameId = uint256(bytes32(result));

    //     (bool success2,) = address(proxy).call(abi.encodeWithSignature("start(uint256)", myGameId));
    //     require(success2, "game not started");
    //     vm.stopPrank();

    //     vm.startPrank(ADMIN);
    // }
}

