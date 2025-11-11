<!-- PROJECT SHIELDS -->

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <!-- <a href="https://github.com/Keyring-Network/euler-keyring-sidepocket-hook">
    <img src="assets/icon.svg" alt="Logo" width="80" height="80">
  </a> -->

  <h3 align="center">Euler Keyring Side Pocket Hook</h3>

  <p align="center">
    Access control hook for Euler vaults with pro-rata withdrawal limits
    <br />
    <a href="https://github.com/Keyring-Network/euler-keyring-sidepocket-hook/issues/new?labels=bug&template=bug-report---.md">Report Bug</a>
    ·
    <a href="https://github.com/Keyring-Network/euler-keyring-sidepocket-hook/issues/new?labels=enhancement&template=feature-request---.md">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
        <li><a href="#main-contract-functions">Main Contract Functions</a></li>
        <li><a href="#custom-errors">Custom Errors</a></li>
      </ul>
    </li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->

## About The Project

This project implements `HookTargetAccessControlKeyringSidePocket`, a hook contract for Euler vaults that extends `HookTargetAccessControlKeyring` with side pocket functionality for managing withdrawal limits.

### Key Features

- **Access Control**: Keyring-based authentication for vault operations, ensuring only authorized users can interact with the vault
- **Pro-Rata Withdrawal Limits**: Enforces withdrawal limits based on a cumulative liquidity index system, ensuring proportional withdrawal rights based on supplied assets
- **Side Pocket Functionality**: Toggleable side pocket feature that can be enabled or disabled by administrators
- **Transfer Restrictions**: Prevents transfers of vault shares to maintain position integrity
- **Cumulative Tracking**: Tracks total withdrawn amounts per user to enforce withdrawal limits accurately

### How It Works

The contract uses a cumulative withdrawal liquidity index to calculate each user's withdrawal allowance:

1. **Initialization**: Administrators set the cumulative withdrawal liquidity index with:

   - `assetsAvailableForWithdrawal`: Total assets available for withdrawal in the current period
   - `totalSuppliedAssets`: Total assets supplied by all users for proportional calculation

2. **Withdrawal Calculation**: When a user attempts to withdraw, the contract calculates their allowed withdrawal amount using:

   ```
   allowedAssets = (assetsAvailableForWithdrawal * (totalWithdrawn + assetsSupplied)) / totalSuppliedAssets - totalWithdrawn
   ```

3. **Access Control**: All vault operations require Keyring credential verification, ensuring only authorized users can interact with the vault.

4. **Side Pocket Toggle**: The side pocket functionality can be enabled or disabled, allowing administrators to control when withdrawal limits are enforced.

### Built With

- Solidity
- Foundry
- Soldeer

<!-- GETTING STARTED -->

## Getting Started

### Prerequisites

Make sure you have git, rust, and foundry installed and configured on your system.

### Installation

Clone the repo,

```shell
git clone https://github.com/Keyring-Network/euler-keyring-sidepocket-hook.git
```

cd into the repo, install the necessary dependencies, and build the project,

```shell
cd euler-keyring-sidepocket-hook
make
```

Run tests by executing,

```shell
make test
```

That's it, you are good to go now!

### Main Contract Functions

#### `setCumulativeWithdrawalLiquidityIndex(uint256 assetsAvailableForWithdrawal, uint256 totalSuppliedAssets)`

Sets the cumulative withdrawal liquidity index for the current withdrawal period. Can only be called by an address with `DEFAULT_ADMIN_ROLE`.

#### `toggleSidePocket()`

Toggles the side pocket functionality on or off. Can only be called by an address with `DEFAULT_ADMIN_ROLE`.

#### `getAssetsAvailableForWithdrawal(address user)`

Calculates and returns the amount of assets a user is currently allowed to withdraw based on their supplied assets and the cumulative withdrawal liquidity index.

#### `withdraw(uint256 amount, address, address owner)`

Hook function that intercepts EVault withdraw operations to enforce withdrawal limits and authenticate users.

#### `redeem(uint256 shares, address, address owner)`

Hook function that intercepts EVault redeem operations to enforce withdrawal limits and authenticate users.

#### `transfer(address, uint256)`, `transferFrom(address, address, uint256)`, `transferFromMax(address, address)`

These functions are disabled and always revert to prevent vault share transfers.

### Custom Errors

The contract defines several custom errors that may be thrown:

- **`ValueZero()`**: Thrown when attempting to set the cumulative withdrawal liquidity index with zero values
- **`WithdrawalAmountExceedsLimit(uint256 amount, uint256 allowedAssetsForWithdrawal)`**: Thrown when a user attempts to withdraw more than their allowed limit
- **`Disallowed()`**: Thrown when attempting to transfer vault shares (transfers are disabled)
- **`IndexNotInitialized()`**: Thrown when trying to withdraw or check withdrawal allowance before the cumulative withdrawal liquidity index is initialized

<!-- ROADMAP -->

## Roadmap

- [x] Smart contract development
- [x] Testing
- [x] Documentation

See the [open issues](https://github.com/Keyring-Network/euler-keyring-sidepocket-hook/issues) for a full list of proposed features (and known issues).

<!-- CONTRIBUTING -->

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<!-- LICENSE -->

## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[contributors-shield]: https://img.shields.io/github/contributors/Keyring-Network/euler-keyring-sidepocket-hook.svg?style=for-the-badge
[contributors-url]: https://github.com/Keyring-Network/euler-keyring-sidepocket-hook/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/Keyring-Network/euler-keyring-sidepocket-hook.svg?style=for-the-badge
[forks-url]: https://github.com/Keyring-Network/euler-keyring-sidepocket-hook/network/members
[stars-shield]: https://img.shields.io/github/stars/Keyring-Network/euler-keyring-sidepocket-hook.svg?style=for-the-badge
[stars-url]: https://github.com/Keyring-Network/euler-keyring-sidepocket-hook/stargazers
[issues-shield]: https://img.shields.io/github/issues/Keyring-Network/euler-keyring-sidepocket-hook.svg?style=for-the-badge
[issues-url]: https://github.com/Keyring-Network/euler-keyring-sidepocket-hook/issues
[license-shield]: https://img.shields.io/github/license/Keyring-Network/euler-keyring-sidepocket-hook.svg?style=for-the-badge
[license-url]: https://github.com/Keyring-Network/euler-keyring-sidepocket-hook/blob/master/LICENSE.txt
[linktree-url]: https://linktr.ee/mgnfy.view
