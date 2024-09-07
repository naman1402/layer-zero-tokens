// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./LZERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NativeToken is LZERC20, ReentrancyGuard {
    constructor(address _lzEndpoint) LZERC20("NativeToken", "NT", _lzEndpoint) {}
}