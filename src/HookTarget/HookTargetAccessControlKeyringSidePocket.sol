// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {IEVault} from "../../lib/euler-vault-kit/src/interfaces/IEVault.sol";

import {HookTargetAccessControlKeyring} from "./HookTargetAccessControlKeyring.sol";

/// @title HookTargetAccessControlKeyringSidePocket.
/// @author mgnfy-view.
/// @notice Manages withdrawal limits for vault positions using a cumulative liquidity index system.
/// @dev Extends HookTargetAccessControlKeyring to add pro-rata withdrawal enforcement based on supplied assets.
contract HookTargetAccessControlKeyringSidePocket is HookTargetAccessControlKeyring {
    /// @notice Configuration for tracking cumulative withdrawal availability.
    /// @dev Used to calculate pro-rata withdrawal limits based on user's supplied assets.
    struct CumulativeWithdrawalLiquidityIndex {
        /// @notice Total assets available for withdrawal in the current period.
        uint256 assetsAvailableForWithdrawal;
        /// @notice Total assets supplied by all users for proportional calculation.
        uint256 totalSuppliedAssets;
    }

    /// @notice The target debt vault where users have deposited assets.
    IEVault public immutable targetDebtVault;

    /// @notice Current active withdrawal segment configuration.
    /// @dev Updated by admin when starting a new withdrawal period.
    CumulativeWithdrawalLiquidityIndex public cumulativeWithdrawalLiquidityIndex;

    /// @notice Tracks the total amount withdrawn by each user.
    /// @dev Maps user address to their cumulative withdrawn amount.
    mapping(address user => uint256 totalWithdrawnAmount) public userWithdrawnAmounts;

    /// @notice Emitted when the cumulative withdrawal liquidity index is updated.
    /// @param assetsAvailableForWithdrawal The new total assets available for withdrawal.
    /// @param totalSuppliedAssets The new total supplied assets for calculation.
    event CumulativeWithdrawalLiquidityIndexSet(
        uint256 indexed assetsAvailableForWithdrawal, uint256 indexed totalSuppliedAssets
    );

    /// @notice Thrown when a required value is zero.
    error ValueZero();

    /// @notice Thrown when withdrawal amount exceeds the user's allowed limit.
    /// @param amount The requested withdrawal amount.
    /// @param allowedAssetsForWithdrawal The maximum amount the user can withdraw.
    error WithdrawalAmountExceedsLimit(uint256 amount, uint256 allowedAssetsForWithdrawal);

    /// @notice Thrown when attempting to transfer vault shares (transfers are disabled).
    error Disallowed();

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

    /// @notice Sets the cumulative withdrawal liquidity index for the current withdrawal period.
    /// @dev Can only be called by an address with DEFAULT_ADMIN_ROLE.
    /// @param assetsAvailableForWithdrawal Total assets available for withdrawal in this period.
    /// @param totalSuppliedAssets Total supplied assets used for pro-rata calculation.
    function setCumulativeWithdrawalLiquidityIndex(uint256 assetsAvailableForWithdrawal, uint256 totalSuppliedAssets)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (assetsAvailableForWithdrawal == 0 || totalSuppliedAssets == 0) revert ValueZero();

        cumulativeWithdrawalLiquidityIndex.assetsAvailableForWithdrawal = assetsAvailableForWithdrawal;
        cumulativeWithdrawalLiquidityIndex.totalSuppliedAssets = totalSuppliedAssets;

        emit CumulativeWithdrawalLiquidityIndexSet(assetsAvailableForWithdrawal, totalSuppliedAssets);
    }

    /// @notice Intercepts EVault withdraw operations to enforce withdrawal limits and authenticate users.
    /// @dev Hook function called before vault withdrawal execution.
    /// @param amount The amount of assets to withdraw.
    /// @param owner The address whose balance will be debited.
    function withdraw(uint256 amount, address, address owner) external override {
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

    /// @notice Disabled transfer function to prevent vault share transfers.
    /// @dev Always reverts to enforce non-transferability of vault positions.
    /// @return bool Never returns, always reverts.
    function transfer(address, uint256) external pure returns (bool) {
        revert Disallowed();
    }

    /// @notice Disabled transferFrom function to prevent vault share transfers.
    /// @dev Always reverts to enforce non-transferability of vault positions.
    /// @return bool Never returns, always reverts.
    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert Disallowed();
    }

    /// @notice Disabled transferFromMax function to prevent vault share transfers.
    /// @dev Always reverts to enforce non-transferability of vault positions.
    /// @return bool Never returns, always reverts.
    function transferFromMax(address, address) external pure returns (bool) {
        revert Disallowed();
    }

    /// @notice Validates and records a user's withdrawal against their allowed limit.
    /// @dev Calculates pro-rata withdrawal allowance based on cumulative liquidity index.
    /// Updates user's total withdrawn amount upon successful validation.
    /// @param user The address attempting to withdraw.
    /// @param amount The amount of assets to withdraw.
    function _allowExit(address user, uint256 amount) internal {
        uint256 allowedAssetsForWithdrawal = getAssetsAvailableForWithdrawal(user);

        if (amount > allowedAssetsForWithdrawal) {
            revert WithdrawalAmountExceedsLimit(amount, allowedAssetsForWithdrawal);
        }

        userWithdrawnAmounts[user] += amount;
    }

    /// @notice Calculates the amount of assets a user is currently allowed to withdraw.
    /// @dev Computes pro-rata withdrawal entitlement based on the cumulative withdrawal liquidity index.
    /// The calculation uses (totalWithdrawnAmount + assetsSupplied) to represent the user's original position,
    /// assuming their vault balance decreases proportionally with withdrawals.
    /// @param user The address to check withdrawal allowance for.
    /// @return The amount of assets the user can withdraw in the current period.
    function getAssetsAvailableForWithdrawal(address user) public view returns (uint256) {
        uint256 assetsSupplied = targetDebtVault.convertToAssets(targetDebtVault.balanceOf(user));
        uint256 totalWithdrawnAmount = userWithdrawnAmounts[user];
        uint256 maxWithdrawableAssets = (
            cumulativeWithdrawalLiquidityIndex.assetsAvailableForWithdrawal * (totalWithdrawnAmount + assetsSupplied)
        ) / cumulativeWithdrawalLiquidityIndex.totalSuppliedAssets;

        return maxWithdrawableAssets - totalWithdrawnAmount;
    }
}
