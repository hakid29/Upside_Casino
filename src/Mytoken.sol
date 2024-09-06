// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CUBC is ERC20 {
    constructor() ERC20("Bet Coin", "BC") {
        _mint(msg.sender, type(uint256).max);
    }

    function freeMint() public {
        _mint(msg.sender, 100 ether);
    }
}

// token address : 0x4776dAD25Ec402844B0Ac950177dDE05A1e616c1