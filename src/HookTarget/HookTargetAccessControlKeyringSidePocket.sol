// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {IEVault} from "../../lib/euler-vault-kit/src/interfaces/IEVault.sol";

import {HookTargetAccessControlKeyring} from "./HookTargetAccessControlKeyring.sol";

/// @title HookTargetAccessControlKeyringSidePocket.
/// @author mgnfy-view.
/// @notice Implements a side pocket mechanism for controlled withdrawals from an EVault.
/// @dev Extends HookTargetAccessControlKeyring to add withdrawal segmentation functionality.
contract HookTargetAccessControlKeyringSidePocket is HookTargetAccessControlKeyring {
    /// @notice Represents a withdrawal period with specific allocation rules.
    /// @dev Each segment defines how much of the total supplied assets can be withdrawn.
    /// @param index Sequential identifier for the withdrawal segment (starts at 1).
    /// @param assetsAvailableForWithdrawal Total amount of assets available for withdrawal in this segment.
    /// @param totalSuppliedAssets Total assets supplied across all users at segment creation.
    struct WithdrawalSegment {
        uint256 index;
        uint256 assetsAvailableForWithdrawal;
        uint256 totalSuppliedAssets;
    }

    /// @notice The target debt vault where users have deposited assets.
    IEVault public immutable targetDebtVault;

    /// @notice Current active withdrawal segment configuration.
    /// @dev Updated by admin when starting a new withdrawal period.
    WithdrawalSegment public withdrawalSegment;

    /// @notice Tracks withdrawal allowances for each user in each segment.
    /// @dev A value of type(uint256).max indicates the user has fully withdrawn for that segment.
    mapping(address user => mapping(uint256 withdrawalSegment => uint256 withdrawableAmount)) public withdrawableAmounts;

    /// @notice Emitted when a new withdrawal segment is initiated.
    /// @param withdrawalSegment The newly created withdrawal segment configuration.
    event StartedNextWithdrawalSegment(WithdrawalSegment indexed withdrawalSegment);

    /// @notice Thrown when a required value is zero.
    error ValueZero();

    /// @notice Thrown when attempting to withdraw before any segment has been started.
    error WithdrawalSegmentZero();

    /// @notice Thrown when a user attempts to withdraw again after exhausting their segment allocation.
    error AlreadyWithdrawnThisSegment();

    /// @notice Thrown when withdrawal amount exceeds the user's allowed limit.
    /// @param amount The requested withdrawal amount.
    /// @param allowedAssetsForWithdrawal The maximum amount the user can withdraw.
    error WithdrawalAmountExceedsLimit(uint256 amount, uint256 allowedAssetsForWithdrawal);

    /// @notice Initializes the side pocket contract with access control and vault configuration.
    /// @dev Sets up Keyring authentication and links to the target debt vault.
    /// @param _evc Address of the Ethereum Vault Connector.
    /// @param _admin Address that will receive DEFAULT_ADMIN_ROLE privileges.
    /// @param _eVaultFactory Address of the EVault factory contract.
    /// @param _keyring Address of the keyring contract for credential verification.
    /// @param _policyId Policy identifier for access control rules.
    /// @param _targetDebtVault Address of the EVault where users have deposited assets.
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

    /// @notice Initiates a new withdrawal segment with specified allocation parameters.
    /// @dev Only callable by addresses with DEFAULT_ADMIN_ROLE.
    /// @dev Increments the segment index and sets new withdrawal limits.
    /// @param assetsAvailableForWithdrawal Total assets that can be withdrawn across all users in this segment.
    /// @param totalSuppliedAssets Total assets supplied by all users (used for proportional calculations).
    function startNextWithdrawalSegment(uint256 assetsAvailableForWithdrawal, uint256 totalSuppliedAssets)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (assetsAvailableForWithdrawal == 0 || totalSuppliedAssets == 0) revert ValueZero();

        withdrawalSegment.index++;
        withdrawalSegment.assetsAvailableForWithdrawal = assetsAvailableForWithdrawal;
        withdrawalSegment.totalSuppliedAssets = totalSuppliedAssets;

        emit StartedNextWithdrawalSegment(withdrawalSegment);
    }

    /// @notice Intercepts EVault withdraw operations to enforce withdrawal limits and authenticate users.
    /// @dev Hook function called before vault withdrawal execution.
    /// @param amount The amount of assets to withdraw.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address whose balance will be debited.
    function withdraw(uint256 amount, address receiver, address owner) external override {
        _allowExit(owner, amount);
        _authenticateCallerAndAccount(owner);
    }

    /// @notice Intercepts EVault redeem operations to enforce withdrawal limits and authenticate users.
    /// @dev Hook function called before vault share redemption; converts shares to assets.
    /// @param shares The number of vault shares to redeem.
    /// @param owner The address whose shares will be burned.
    function redeem(uint256 shares, address, address owner) external override {
        uint256 amount = targetDebtVault.convertToAssets(shares);
        _allowExit(owner, amount);
        _authenticateCallerAndAccount(owner);
    }

    /// @notice Internal function to validate and track user withdrawal allowances.
    /// @dev Calculates proportional withdrawal limit on first withdrawal in a segment.
    /// @dev Uses type(uint256).max as a marker for users who have fully withdrawn.
    /// @param user The address attempting to withdraw.
    /// @param amount The amount of assets to withdraw.
    function _allowExit(address user, uint256 amount) internal {
        if (withdrawalSegment.index == 0) revert WithdrawalSegmentZero();
        if (withdrawableAmounts[user][withdrawalSegment.index] == type(uint256).max) {
            revert AlreadyWithdrawnThisSegment();
        }

        uint256 assetsSupplied = targetDebtVault.convertToAssets(targetDebtVault.balanceOf(user));
        uint256 allowedAssetsForWithdrawal = withdrawableAmounts[user][withdrawalSegment.index];

        // Calculate proportional withdrawal limit on first withdrawal in this segment
        if (withdrawableAmounts[user][withdrawalSegment.index] == 0) {
            withdrawableAmounts[user][withdrawalSegment.index] = allowedAssetsForWithdrawal = (
                assetsSupplied * withdrawalSegment.assetsAvailableForWithdrawal
            ) / withdrawalSegment.totalSuppliedAssets;
        }

        if (amount > allowedAssetsForWithdrawal) {
            revert WithdrawalAmountExceedsLimit(amount, allowedAssetsForWithdrawal);
        }

        // Deduct withdrawn amount from user's allowance
        withdrawableAmounts[user][withdrawalSegment.index] -= amount;

        // Mark as fully withdrawn if allowance is exhausted
        if (withdrawableAmounts[user][withdrawalSegment.index] == 0) {
            withdrawableAmounts[user][withdrawalSegment.index] = type(uint256).max;
        }
    }
}
