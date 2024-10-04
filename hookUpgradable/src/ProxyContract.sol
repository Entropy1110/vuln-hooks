// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";



contract ProxyContract is Proxy {
    /// @notice If set, delegatecall to implementation after tracking call
    address internal impl;

    /// @notice exposes implementation contract address
    function _implementation() internal view override returns (address) {
        return impl;
    }

    function setImplementation(address _impl) external {
        impl = _impl;
    }
    function _fallback() internal override {
        super._fallback();
    }

    receive() external payable {}
}
