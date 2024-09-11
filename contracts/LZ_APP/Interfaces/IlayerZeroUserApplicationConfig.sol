// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;


interface ILayerZeroUserApplicationConfig {

    function setConfig(uint16 _chainId, address _endpoint, uint256 _configType, bytes calldata _config) external;
    function setSendVersion(uint16 _chainId, address _endpoint, uint256 _version) external;
    function setReceiveVersion(uint16 _chainId, address _endpoint, uint256 _version) external;
    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external;
}
