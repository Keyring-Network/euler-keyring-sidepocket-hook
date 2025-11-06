// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockEVault {
    mapping(address => uint256) public balances;
    uint256 public totalAssets;
    uint256 public totalSupply;

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        if (totalSupply == 0) return shares;
        return (shares * totalAssets) / totalSupply;
    }

    function setBalance(address user, uint256 amount) external {
        balances[user] = amount;
    }

    function setTotalAssets(uint256 amount) external {
        totalAssets = amount;
    }

    function setTotalSupply(uint256 amount) external {
        totalSupply = amount;
    }
}
