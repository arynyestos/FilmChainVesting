// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {FILMChain} from "../src/FILMChain.sol";
import {MockFilmToken} from "../test/mocks/MockFilmToken.sol";
import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    address filmTokenOwner = makeAddr("filmOwner");

    struct NetworkConfig {
        address FILMtokenAddress;
    }

    constructor() {
        if (block.chainid == 56) {
            activeNetworkConfig = getBscConfig();
        } else if (block.chainid == 97) {
            activeNetworkConfig = getBscTestnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getBscConfig() public pure returns (NetworkConfig memory bscNetworkConfig) {
        bscNetworkConfig = NetworkConfig({
            FILMtokenAddress: 0x17e842BEC4D8c6FA612A21c087599698dE5aFd0a // Address of the FILM token contract in BSC
        });
    }

    function getBscTestnetConfig() public pure returns (NetworkConfig memory bscNetworkConfig) {
        bscNetworkConfig = NetworkConfig({
            FILMtokenAddress: 0x0d69E450b4a768BFB1146AeE8b3B2886389C5aD2 // Address of the FILM token contract in BSC testnet
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we already have an active network config
        if (activeNetworkConfig.FILMtokenAddress != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        // FILMChain filmToken = new FILMChain();
        MockFilmToken filmToken = new MockFilmToken(msg.sender);
        filmToken.transferOwnership(filmTokenOwner);
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({FILMtokenAddress: address(filmToken)});
    }
}
