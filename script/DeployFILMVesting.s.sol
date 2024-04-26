//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {FILMChain} from "../src/FILMChain.sol";
import {FILMVesting} from "../src/FILMVesting.sol";
import {console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployFILMVesting is Script {
    address filmVestingowner = makeAddr("vestingOwner");

    function run() external returns (FILMVesting, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        address filmToken = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        FILMVesting filmVesting = new FILMVesting(IERC20(filmToken), 1745670053);
        filmVesting.transferOwnership(filmVestingowner); // Only for tests!!!
        vm.stopBroadcast();
        return (filmVesting, helperConfig);
    }
}
