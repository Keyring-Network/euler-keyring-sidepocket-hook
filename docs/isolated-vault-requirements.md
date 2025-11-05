# Isolated Vault Hook Target - Requirements

## Objective

Create a hook target contract extending `HookTargetAccessControlKeyring` that restricts withdrawals proportionally based on outstanding debt in a target vault. This implements a "side-pocket" mechanism to ensure fair distribution of frozen assets across all depositors during debt uncertainty.

## Core Functionality

### Withdrawal Restriction Formula

For each user attempting to withdraw from the protected vault (USDC), freeze a proportional amount based on:

```
Frozen Ratio = Outstanding Debt in Target Vault / Protected Vault Total Supply
Maximum Withdrawable = User Balance × (1 - Frozen Ratio)
```

**Example**: If total supply is 100M and target debt is 6M, frozen ratio = 6%. User with 10K balance can withdraw max 9.4K.

### Key Requirements

1. **Inheritance**: Must extend `HookTargetAccessControlKeyring` 
   - Reason: Only one hook contract allowed per vault
   - Preserve existing access control and Keyring credential functionality

2. **Configurable Parameters**:
   - Target debt vault address (sdeUSD vault to monitor)
   - Freezing enabled/disabled flag
   - Override capabilities for emergency governance actions

3. **Hook Interception**:
   - Intercept withdrawal and redeem operations
   - Calculate real-time frozen ratio
   - Enforce maximum withdrawal limits
   - Allow operations under threshold to proceed normally

4. **Governance Controls**:
   - Enable/disable freezing mechanism
   - Update target debt vault address
   - Manual override for emergency scenarios
   - Role-based permissions via existing access control

## Technical Design Considerations

### Architecture

```
HookTargetAccessControlKeyring (existing)
    ↓ (inheritance)
IsolatedVaultHookTarget (new)
    ↓ (adds)
- Debt vault tracking
- Withdrawal restriction logic
- Side-pocket calculations
```

### State Variables Needed

- `targetDebtVault`: Address of vault whose debt determines freeze ratio
- `freezingEnabled`: Boolean flag for governance control
- Leverage existing access control roles from parent

### Constructor Requirements

Must accept all parent constructor parameters:
- `_evc`: Address of the Ethereum Vault Connector
- `_admin`: Address to be granted DEFAULT_ADMIN_ROLE
- `_eVaultFactory`: Address of the EVault factory
- `_keyring`: Address of the Keyring contract
- `_policyId`: Policy ID for credential checking

Plus new parameters:
- `_targetDebtVault`: Initial target debt vault address
- `_freezingEnabled`: Initial freezing state

### Deployment & Migration Considerations

**Important**: This is a **new deployment**, not an upgrade of existing contract.

- Cannot reuse existing HookTargetAccessControlKeyring state
- Must reconfigure all access control roles after deployment
- Must grant roles to same addresses as current hook target
- Vault must be updated to point to new hook target address
- Consider multi-sig coordination for atomic switchover

### Functions to Override/Add

- Override withdrawal/redeem hooks to enforce limits
- Add debt ratio calculation view function
- Add governance functions to configure parameters
- Add view functions for users to check their frozen amounts

### Integration Points

- **EVC Integration**: Maintain compatibility with Ethereum Vault Connector
- **EVault Factory**: Continue to validate caller is recognized factory proxy
- **Access Control**: Preserve role-based permissions and Keyring checks
- **Debt Vault Interface**: Query debt and supply from target vault

## Use Cases

### Primary Flow

1. User calls withdraw on protected vault
2. Hook intercepts and queries target vault debt
3. Calculates frozen ratio from debt/supply
4. If requested amount ≤ max withdrawable: proceeds
5. If requested amount > max withdrawable: reverts

### Governance Flow

1. Governance enables/disables freezing mechanism
2. Governance updates target vault address if needed
3. Users regain full access when freezing disabled

## Success Criteria

1. ✅ Withdrawals respect frozen ratio based on target vault debt
2. ✅ Governance can enable/disable and configure the mechanism
3. ✅ Existing HookTargetAccessControlKeyring functionality preserved
4. ✅ Users receive clear reverts when attempting over-limit withdrawals
5. ✅ View functions provide transparency on frozen amounts
6. ✅ EVC and factory integration remains compatible
