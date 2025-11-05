// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0 ^0.8.19;

import {IEVault} from "../../lib/euler-vault-kit/src/interfaces/IEVault.sol";

import {HookTargetAccessControlKeyring} from "./HookTargetAccessControlKeyring.sol";

contract HookTargetAccessControlKeyringSidePocket is HookTargetAccessControlKeyring {
    IEVault public immutable targetDebtVault;

    constructor(
        address _evc,
        address _admin,
        address _eVaultFactory,
        address _keyring,
        uint32 _policyId,
        address _targetDebtVault
    ) HookTargetAccessControlKeyring(_evc, _admin, _eVaultFactory, _keyring, _policyId) {
        targetDebtVault = IEVault(_targetDebtVault);
    }

    /// @notice Intercepts EVault withdraw operations to authenticate the caller and the owner
    /// @param owner The address whose balance will change
    function withdraw(uint256 amount, address receiver, address owner) external view override {
        uint256 shareBalance = targetDebtVault.balanceOf(owner);
        uint256 assetsSupplied = targetDebtVault.convertToAssets(shareBalance);
        _authenticateCallerAndAccount(owner);
    }

    /// @notice Intercepts EVault redeem operations to authenticate the caller and the owner
    /// @param owner The address whose balance will change
    function redeem(uint256, address, address owner) external view override {
        _authenticateCallerAndAccount(owner);
    }
}
