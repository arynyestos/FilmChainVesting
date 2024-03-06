//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {FILMChain} from "../src/FILMChain.sol";
import {console} from "forge-std/Test.sol";

contract DeployFILMVesting is Script {
    function run() external returns (FILMChain) {
        vm.startBroadcast();
        FILMChain filmChain = new FILMChain();
        vm.stopBroadcast();
        return (filmChain);
    }
}
