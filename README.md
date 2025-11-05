# Hook Target Smart Contracts

This repository contains the separated smart contract files for the Hook Target system, organized into a modular directory structure for better maintainability and clarity.

## Directory Structure

```
hooktarget/
├── lib/
│   ├── ethereum-vault-connector/
│   │   └── src/
│   │       ├── ExecutionContext.sol
│   │       ├── interfaces/
│   │       │   └── IEthereumVaultConnector.sol
│   │       └── utils/
│   │           └── EVCUtil.sol
│   │
│   ├── euler-vault-kit/
│   │   └── src/
│   │       ├── GenericFactory/
│   │       │   ├── BeaconProxy.sol
│   │       │   ├── GenericFactory.sol
│   │       │   └── MetaProxyDeployer.sol
│   │       └── interfaces/
│   │           └── IHookTarget.sol
│   │
│   ├── openzeppelin-contracts/
│   │   └── contracts/
│   │       ├── access/
│   │       │   ├── IAccessControl.sol
│   │       │   └── extensions/
│   │       │       └── IAccessControlEnumerable.sol
│   │       └── utils/
│   │           ├── introspection/
│   │           │   └── IERC165.sol
│   │           └── structs/
│   │               └── EnumerableSet.sol
│   │
│   └── openzeppelin-contracts-upgradeable/
│       └── contracts/
│           ├── access/
│           │   ├── AccessControlUpgradeable.sol
│           │   └── extensions/
│           │       └── AccessControlEnumerableUpgradeable.sol
│           ├── proxy/
│           │   └── utils/
│           │       └── Initializable.sol
│           └── utils/
│               ├── ContextUpgradeable.sol
│               └── introspection/
│                   └── ERC165Upgradeable.sol
│
└── src/
    ├── AccessControl/
    │   └── SelectorAccessControl.sol
    └── HookTarget/
        ├── BaseHookTarget.sol
        └── HookTargetAccessControlKeyring.sol
```

## File Descriptions

### Library Files (Ethereum Vault Connector)

- **ExecutionContext.sol**: Manages execution context bit fields for EVC operations
- **IEthereumVaultConnector.sol**: Interface defining EVC contract methods
- **EVCUtil.sol**: Abstract utility contract for EVC interaction and authentication

### Library Files (Euler Vault Kit)

- **BeaconProxy.sol**: Proxy contract forwarding calls to an implementation fetched from a beacon
- **GenericFactory.sol**: Factory for creating upgradeable and non-upgradeable proxy contracts
- **MetaProxyDeployer.sol**: Deploys minimal proxies with metadata based on EIP-3448
- **IHookTarget.sol**: Interface for hook target contract validation

### Library Files (OpenZeppelin Contracts)

- **IAccessControl.sol**: Interface for role-based access control
- **IAccessControlEnumerable.sol**: Interface extending IAccessControl with enumeration
- **IERC165.sol**: Interface for ERC-165 standard interface detection
- **EnumerableSet.sol**: Library for managing sets of primitive types

### Library Files (OpenZeppelin Contracts Upgradeable)

- **Initializable.sol**: Base contract for upgradeable contracts with initialization protection
- **ContextUpgradeable.sol**: Provides execution context information for upgradeable contracts
- **ERC165Upgradeable.sol**: Upgradeable implementation of ERC-165 interface detection
- **AccessControlUpgradeable.sol**: Upgradeable role-based access control implementation
- **AccessControlEnumerableUpgradeable.sol**: Upgradeable access control with enumeration support

### Application Files (Custom Implementation)

- **SelectorAccessControl.sol**: Utility contract for function selector-based access control with EVC support
- **BaseHookTarget.sol**: Base contract for hook targets integrated with EVK factory
- **HookTargetAccessControlKeyring.sol**: Hook target with access control and Keyring credential checking

## Key Contracts

### Core Application Contracts (`src/`)

1. **HookTargetAccessControlKeyring** (`src/HookTarget/HookTargetAccessControlKeyring.sol`)

   - Main hook target contract with access control and Keyring credential checking
   - Intercepts EVault operations (deposit, mint, withdraw, redeem, etc.)
   - Supports role-based access control with wildcard permissions
   - Integrates with Keyring for credential validation

2. **BaseHookTarget** (`src/HookTarget/BaseHookTarget.sol`)

   - Base contract for hook targets
   - Validates caller is a recognized EVault factory proxy
   - Extracts message sender from calldata in vault context

3. **SelectorAccessControl** (`src/AccessControl/SelectorAccessControl.sol`)
   - Function selector-based access control utility
   - EVC-integrated role management
   - Supports wildcard and specific selector permissions

### Library Contracts (`lib/`)

#### Ethereum Vault Connector

- **ExecutionContext.sol**: Bit-field based execution context management
- **IEthereumVaultConnector.sol**: EVC interface definition
- **EVCUtil.sol**: Utilities for EVC interaction

#### Euler Vault Kit

- **BeaconProxy.sol**: Beacon-based proxy implementation
- **GenericFactory.sol**: Factory for creating proxy contracts
- **MetaProxyDeployer.sol**: Meta-proxy deployment utilities
- **IHookTarget.sol**: Hook target interface

#### OpenZeppelin Contracts

- Access control interfaces and implementations
- ERC-165 interface detection
- Enumerable sets for managing collections

## Migration Notes

All contracts maintain their original functionality and interfaces. The separation was done purely for organization and does not affect the runtime behavior of the contracts.

### Import Paths

When referencing these files, use relative import paths based on their location in the file tree. For example:

- From `src/HookTarget/HookTargetAccessControlKeyring.sol`:
  - `import {BaseHookTarget} from "./BaseHookTarget.sol";`
  - `import {SelectorAccessControl} from "../AccessControl/SelectorAccessControl.sol";`

## Getting Started

### Prerequisites

- Solidity ^0.8.19
- Compatible Ethereum development environment

### Integration

To use these contracts in your project:

1. **Ensure proper import paths** - All imports are relative and structured according to the directory hierarchy
2. **Deploy HookTargetAccessControlKeyring** - Provide required parameters:
   - `_evc`: Ethereum Vault Connector address
   - `_admin`: Admin address for role management
   - `_eVaultFactory`: EVault factory address
   - `_keyring`: Keyring contract address
   - `_policyId`: Policy ID for credential checking

### Configuration Example

```solidity
// Deploy the hook target
HookTargetAccessControlKeyring hookTarget = new HookTargetAccessControlKeyring(
    evcAddress,
    adminAddress,
    eVaultFactoryAddress,
    keyringAddress,
    policyIdValue
);

// Grant roles as needed
hookTarget.grantRole(
    keccak256("SELECTOR_ROLE"),
    authorizedCaller
);
```

## Security Considerations

1. **Access Control**: Uses role-based access control with EVC integration
2. **Keyring Credentials**: Optional Keyring-based credential validation
3. **Privileged Accounts**: Special handling for accounts with PRIVILEGED_ACCOUNT_ROLE
4. **EVC Integration**: All role management operations require proper EVC authentication

## File Organization Rationale

The contracts are organized following their source paths from the original libraries:

- **lib/ethereum-vault-connector**: EVC protocol utilities
- **lib/euler-vault-kit**: Euler vault infrastructure
- **lib/openzeppelin-contracts**: Standard OpenZeppelin contracts
- **lib/openzeppelin-contracts-upgradeable**: Upgradeable versions
- **src/**: Custom application-specific contracts

This structure mirrors the actual library organization, making it easy to:

- Track contract origins
- Update library versions
- Understand dependencies
- Maintain consistency with upstream libraries

## License

All contracts are licensed under GPL-2.0-or-later.

### Technical Details

All files use: `SPDX-License-Identifier: GPL-2.0-or-later`
All files use: `pragma solidity >=0.8.0 ^0.8.19;`
