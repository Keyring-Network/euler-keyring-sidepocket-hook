// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.11.0/src/Script.sol";

import {HookTargetAccessControlKeyringSidePocket} from "src/HookTarget/HookTargetAccessControlKeyringSidePocket.sol";

contract DeployHookTargetAccessControlKeyringSidePocket is Script {
    uint256 public privateKey;
    address public admin;
    address public evc;
    address public factory;
    address public keyring;
    uint32 public policyId;
    address public targetDebtVault;

    function setUp() public {
        privateKey = vm.envUint("PRIVATE_KEY");
        admin = vm.envAddress("ADMIN");
        evc = vm.envAddress("EVC");
        factory = vm.envAddress("FACTORY");
        keyring = vm.envAddress("KEYRING");
        policyId = uint32(vm.envUint("POLICY_ID"));
        targetDebtVault = vm.envAddress("TARGET_DEBT_VAULT");
    }

    function run() public returns (HookTargetAccessControlKeyringSidePocket) {
        vm.startBroadcast(privateKey);
        HookTargetAccessControlKeyringSidePocket hook =
            new HookTargetAccessControlKeyringSidePocket(evc, admin, factory, keyring, policyId, targetDebtVault);
        vm.stopBroadcast();

        return hook;
    }
}
