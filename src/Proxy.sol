pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MyProxy is ERC1967Proxy {
    constructor(address logic, bytes memory data) ERC1967Proxy(logic, data) {
    }    
}

// forge create --rpc-url upside:center39383817284134737847833@rpc.exploit101.com
// --private-key