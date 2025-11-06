// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockKeyring {
    mapping(address => mapping(uint32 => bool)) public credentials;

    function checkCredential(address user, uint32 policyId) external view returns (bool) {
        return credentials[user][policyId];
    }

    function setCredential(address user, uint32 policyId, bool valid) external {
        credentials[user][policyId] = valid;
    }
}
