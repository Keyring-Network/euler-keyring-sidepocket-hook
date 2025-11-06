// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {Test} from "forge-std-1.11.0/src/Test.sol";

import {HookTargetAccessControlKeyringSidePocket} from "src/HookTarget/HookTargetAccessControlKeyringSidePocket.sol";
import {MockEVault} from "./mocks/MockEVault.sol";
import {MockEVaultFactory} from "./mocks/MockEVaultFactory.sol";
import {MockKeyring} from "./mocks/MockKeyring.sol";
import {MockEVC} from "./mocks/MockEVC.sol";

contract HookTargetAccessControlKeyringSidePocketTest is Test {
    address public admin;
    address public user1;
    address public user2;
    address public vault;

    HookTargetAccessControlKeyringSidePocket public hookTarget;
    MockEVC public evc;
    MockEVaultFactory public factory;
    MockKeyring public keyring;
    MockEVault public targetDebtVault;

    uint32 public constant POLICY_ID = 1;

    event CumulativeWithdrawalLiquidityIndexSet(
        uint256 indexed assetsAvailableForWithdrawal, uint256 indexed totalSuppliedAssets
    );

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        vault = makeAddr("vault");

        // Deploy mock contracts
        evc = new MockEVC();
        factory = new MockEVaultFactory();
        keyring = new MockKeyring();
        targetDebtVault = new MockEVault();

        // Deploy hook target
        vm.prank(admin);
        hookTarget = new HookTargetAccessControlKeyringSidePocket(
            address(evc), admin, address(factory), address(keyring), POLICY_ID, address(targetDebtVault)
        );

        // Setup vault as factory proxy
        factory.addProxy(vault);
    }

    function test_Constructor() public view {
        assertEq(address(hookTarget.targetDebtVault()), address(targetDebtVault));
        assertEq(address(hookTarget.keyring()), address(keyring));
        assertEq(hookTarget.policyId(), POLICY_ID);
    }

    function test_SetCumulativeWithdrawalLiquidityIndex_Success() public {
        uint256 assetsAvailable = 1_000_000e18;
        uint256 totalSupplied = 2_000_000e18;

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit CumulativeWithdrawalLiquidityIndexSet(assetsAvailable, totalSupplied);

        hookTarget.setCumulativeWithdrawalLiquidityIndex(assetsAvailable, totalSupplied);

        (uint256 storedAvailable, uint256 storedTotal) = hookTarget.cumulativeWithdrawalLiquidityIndex();
        assertEq(storedAvailable, assetsAvailable);
        assertEq(storedTotal, totalSupplied);
    }

    function test_SetCumulativeWithdrawalLiquidityIndex_ZeroAssetsAvailable_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(HookTargetAccessControlKeyringSidePocket.ValueZero.selector);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(0, 1_000_000e18);
    }

    function test_SetCumulativeWithdrawalLiquidityIndex_ZeroTotalSupplied_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(HookTargetAccessControlKeyringSidePocket.ValueZero.selector);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(1_000_000e18, 0);
    }

    function test_SetCumulativeWithdrawalLiquidityIndex_BothZero_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(HookTargetAccessControlKeyringSidePocket.ValueZero.selector);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(0, 0);
    }

    function test_SetCumulativeWithdrawalLiquidityIndex_OnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        hookTarget.setCumulativeWithdrawalLiquidityIndex(1_000_000e18, 2_000_000e18);
    }

    function test_Withdraw_WithinLimit_Success() public {
        // Setup: User has 1M shares worth 1M assets
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 5M available out of 10M total (50% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(5_000_000e18, 10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // User should be able to withdraw up to 500K (50% of their 1M)
        vm.prank(vault);
        hookTarget.withdraw(500_000e18, user1, user1);

        assertEq(hookTarget.userWithdrawnAmounts(user1), 500_000e18);
    }

    function test_Withdraw_ExceedsLimit_Reverts() public {
        // Setup: User has 1M shares worth 1M assets
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 5M available out of 10M total (50% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(5_000_000e18, 10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // User tries to withdraw 600K (exceeds 50% limit of 500K)
        vm.prank(vault);
        vm.expectRevert(
            abi.encodeWithSelector(
                HookTargetAccessControlKeyringSidePocket.WithdrawalAmountExceedsLimit.selector, 600_000e18, 500_000e18
            )
        );
        hookTarget.withdraw(600_000e18, user1, user1);
    }

    function test_Withdraw_CumulativeTracking() public {
        // Setup: User has 1M shares worth 1M assets
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 5M available out of 10M total (50% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(5_000_000e18, 10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // First withdrawal of 200K
        vm.prank(vault);
        hookTarget.withdraw(200_000e18, user1, user1);
        assertEq(hookTarget.userWithdrawnAmounts(user1), 200_000e18);

        // Update user balance after withdrawal (simulating real vault behavior)
        targetDebtVault.setBalance(user1, 800_000e18);

        // Second withdrawal of 300K (total 500K, at limit)
        vm.prank(vault);
        hookTarget.withdraw(300_000e18, user1, user1);
        assertEq(hookTarget.userWithdrawnAmounts(user1), 500_000e18);

        // Update user balance after withdrawal
        targetDebtVault.setBalance(user1, 500_000e18);

        // Third withdrawal should fail (no more allowance despite having balance)
        vm.prank(vault);
        vm.expectRevert();
        hookTarget.withdraw(1e18, user1, user1);
    }

    function test_Redeem_WithinLimit_Success() public {
        // Setup: User has 1M shares worth 1M assets (1:1 ratio)
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 5M available out of 10M total (50% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(5_000_000e18, 10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // User redeems 500K shares (50% of their 1M)
        vm.prank(vault);
        hookTarget.redeem(500_000e18, user1, user1);

        assertEq(hookTarget.userWithdrawnAmounts(user1), 500_000e18);
    }

    function test_Redeem_ExceedsLimit_Reverts() public {
        // Setup: User has 1M shares worth 1M assets
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 5M available out of 10M total (50% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(5_000_000e18, 10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // User tries to redeem 600K shares (exceeds 50% limit)
        vm.prank(vault);
        vm.expectRevert(
            abi.encodeWithSelector(
                HookTargetAccessControlKeyringSidePocket.WithdrawalAmountExceedsLimit.selector, 600_000e18, 500_000e18
            )
        );
        hookTarget.redeem(600_000e18, user1, user1);
    }

    function test_MultipleUsers_ProportionalLimits() public {
        // Setup: User1 has 1M, User2 has 2M shares (both 1:1 asset ratio)
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setBalance(user2, 2_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 5M available out of 10M total (50% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(5_000_000e18, 10_000_000e18);

        // Setup keyring credentials
        keyring.setCredential(user1, POLICY_ID, true);
        keyring.setCredential(user2, POLICY_ID, true);

        // User1 can withdraw 500K (50% of 1M)
        vm.prank(vault);
        hookTarget.withdraw(500_000e18, user1, user1);

        // User2 can withdraw 1M (50% of 2M)
        vm.prank(vault);
        hookTarget.withdraw(1_000_000e18, user2, user2);

        assertEq(hookTarget.userWithdrawnAmounts(user1), 500_000e18);
        assertEq(hookTarget.userWithdrawnAmounts(user2), 1_000_000e18);
    }

    function test_LiquidityCapturePrevention_Scenario() public {
        // Scenario from docs:
        // - Total supply: $14.41M
        // - Uncertain debt: $6.53M
        // - Frozen ratio: 45.3%
        // - User with $1M can withdraw max $547K

        uint256 totalSupply = 14_410_000e18;
        uint256 uncertainDebt = 6_530_000e18;
        uint256 availableForWithdrawal = totalSupply - uncertainDebt; // 7.88M

        // Setup user with 1M balance
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(totalSupply);
        targetDebtVault.setTotalSupply(totalSupply);

        // Set withdrawal index
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(availableForWithdrawal, totalSupply);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // Calculate expected max withdrawal: (7.88M * 1M) / 14.41M ≈ 547K
        uint256 expectedMax = (availableForWithdrawal * 1_000_000e18) / totalSupply;

        // User can withdraw up to expected max
        vm.prank(vault);
        hookTarget.withdraw(expectedMax, user1, user1);

        // Update user balance after withdrawal (simulating real vault behavior)
        targetDebtVault.setBalance(user1, 1_000_000e18 - expectedMax);

        // User cannot withdraw more
        vm.prank(vault);
        vm.expectRevert();
        hookTarget.withdraw(1e18, user1, user1);
    }

    function test_Transfer_Disallowed() public {
        vm.expectRevert(HookTargetAccessControlKeyringSidePocket.Disallowed.selector);
        hookTarget.transfer(user1, 100e18);
    }

    function test_TransferFrom_Disallowed() public {
        vm.expectRevert(HookTargetAccessControlKeyringSidePocket.Disallowed.selector);
        hookTarget.transferFrom(user1, user2, 100e18);
    }

    function test_TransferFromMax_Disallowed() public {
        vm.expectRevert(HookTargetAccessControlKeyringSidePocket.Disallowed.selector);
        hookTarget.transferFromMax(user1, user2);
    }

    function test_Withdraw_OneToOneRatio() public {
        // Setup: User has 1M shares worth 2M assets (2:1 ratio - vault gained value)
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(20_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 10M available out of 20M total (50% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(10_000_000e18, 20_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // User's 1M shares = 2M assets, so they can withdraw 1M assets (50%)
        vm.prank(vault);
        hookTarget.withdraw(1_000_000e18, user1, user1);

        assertEq(hookTarget.userWithdrawnAmounts(user1), 1_000_000e18);
    }

    function test_Redeem_OneToOneRatio() public {
        // Setup: User has 1M shares worth 2M assets (2:1 ratio)
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(20_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 10M available out of 20M total (50% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(10_000_000e18, 20_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // User redeems 500K shares = 1M assets (50% of their value)
        vm.prank(vault);
        hookTarget.redeem(500_000e18, user1, user1);

        assertEq(hookTarget.userWithdrawnAmounts(user1), 1_000_000e18);
    }

    function test_UpdateIndex_ChangesLimits() public {
        // Setup: User has 1M shares worth 1M assets
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Initially: 5M available out of 10M total (50% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(5_000_000e18, 10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // User withdraws 400K
        vm.prank(vault);
        hookTarget.withdraw(400_000e18, user1, user1);

        // Admin increases available to 8M (80% now withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(8_000_000e18, 10_000_000e18);

        // User can now withdraw more: 80% of 1M = 800K, minus already withdrawn 400K = 400K more
        vm.prank(vault);
        hookTarget.withdraw(400_000e18, user1, user1);

        assertEq(hookTarget.userWithdrawnAmounts(user1), 800_000e18);
    }

    function test_FullWithdrawal_100PercentAvailable() public {
        // Setup: User has 1M shares worth 1M assets
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 10M available out of 10M total (100% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(10_000_000e18, 10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // User can withdraw full 1M
        vm.prank(vault);
        hookTarget.withdraw(1_000_000e18, user1, user1);

        assertEq(hookTarget.userWithdrawnAmounts(user1), 1_000_000e18);
    }

    function test_MinimalWithdrawal_LowPercentageAvailable() public {
        // Setup: User has 1M shares worth 1M assets
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Set withdrawal index: 100K available out of 10M total (1% withdrawable)
        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(100_000e18, 10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // User can withdraw 10K (1% of 1M)
        vm.prank(vault);
        hookTarget.withdraw(10_000e18, user1, user1);

        assertEq(hookTarget.userWithdrawnAmounts(user1), 10_000e18);
    }

    function test_Withdraw_RequiresAuthentication() public {
        // Setup: User has balance but no keyring credential
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        vm.prank(admin);
        hookTarget.setCumulativeWithdrawalLiquidityIndex(5_000_000e18, 10_000_000e18);

        // No keyring credential set

        // Withdrawal should fail authentication
        vm.prank(vault);
        vm.expectRevert();
        hookTarget.withdraw(100_000e18, user1, user1);
    }

    function test_Withdraw_IndexNotInitialized_Reverts() public {
        // Setup: User has balance
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // Attempt withdrawal without initializing index
        // Index defaults to zero values, should revert
        vm.prank(vault);
        vm.expectRevert(HookTargetAccessControlKeyringSidePocket.IndexNotInitialized.selector);
        hookTarget.withdraw(100_000e18, user1, user1);
    }

    function test_GetAssetsAvailableForWithdrawal_IndexNotInitialized_Reverts() public {
        // Setup: User has balance
        targetDebtVault.setBalance(user1, 1_000_000e18);

        // Call view function without initializing index
        vm.expectRevert(HookTargetAccessControlKeyringSidePocket.IndexNotInitialized.selector);
        hookTarget.getAssetsAvailableForWithdrawal(user1);
    }

    function test_Redeem_IndexNotInitialized_Reverts() public {
        // Setup: User has balance
        targetDebtVault.setBalance(user1, 1_000_000e18);
        targetDebtVault.setTotalAssets(10_000_000e18);
        targetDebtVault.setTotalSupply(10_000_000e18);

        // Setup keyring credential
        keyring.setCredential(user1, POLICY_ID, true);

        // Attempt redeem without initializing index
        vm.prank(vault);
        vm.expectRevert(HookTargetAccessControlKeyringSidePocket.IndexNotInitialized.selector);
        hookTarget.redeem(100_000e18, user1, user1);
    }
}
