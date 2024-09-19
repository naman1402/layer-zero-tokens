// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../LZERC20.sol";

contract LZERC20Mock is LZERC20 {

    constructor(address _endpoint) LZERC20("OmniERC20", "OFT", _endpoint) {}

    function mintToken(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

