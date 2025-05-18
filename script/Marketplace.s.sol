// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import{Marketplace} from "src/Marketplace.sol";


contract DeployMarketplace is Script {
    function run() external returns (Marketplace) {
        vm.startBroadcast();
        Marketplace marketplace = new Marketplace();
        vm.stopBroadcast();
        return marketplace;
    }
}