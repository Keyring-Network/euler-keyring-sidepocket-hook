// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockEVaultFactory {
    mapping(address => bool) public proxies;

    function addProxy(address proxy) external {
        proxies[proxy] = true;
    }

    function isProxy(address proxy) external view returns (bool) {
        return proxies[proxy];
    }
}
