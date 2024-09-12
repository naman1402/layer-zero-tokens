// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ILZERC721Core.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ILZERC721 is ILZERC721Core, IERC721 {}