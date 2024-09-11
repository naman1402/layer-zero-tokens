// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../LZ_APP/NonblockingLzApp.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract LZERC721Core is NonblockingLzApp, ERC165, ReentrancyGuards {

    uint256 public minGasToTransferAndStore;

    constructor(uint256 _minGasToTransferAndStore, address _lzEndpoint) NonblockingLzApp(_lzEndpoint) {
        require(_minGasToTransferAndStore > 0, "LZERC721Core: minGasToTransferAndStore must be greater than 0");
        minGasToTransferAndStore = _minGasToTransferAndStore;
    }
}

