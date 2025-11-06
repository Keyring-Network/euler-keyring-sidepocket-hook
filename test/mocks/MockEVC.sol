// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockEVC {
    mapping(address => address) public accountOwners;

    function getAccountOwner(address account) external view returns (address) {
        return accountOwners[account];
    }

    function setAccountOwner(address account, address owner) external {
        accountOwners[account] = owner;
    }
}
