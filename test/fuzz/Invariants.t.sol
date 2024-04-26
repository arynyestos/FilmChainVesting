// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {FILMVesting} from "src/FILMVesting.sol";
// import {FILMChain} from "../../src/FILMChain.sol"; // For fork tests
import {MockFilmToken} from "../../test/mocks/MockFilmToken.sol";
import {DeployFILMVesting} from "../../script/DeployFILMVesting.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    FILMVesting filmVesting;
    // FILMChain filmToken; // For fork tests
    MockFilmToken filmToken;
    DeployFILMVesting deployer;
    HelperConfig helperConfig;
    Handler handler;
    address FILM_TOKEN_OWNER = makeAddr("filmOwner");
    address REAL_FILM_OWNER = 0x25f82b92B5888374E06E106edC8a262932c7d55C;
    address FILM_VESTING_OWNER = makeAddr("vestingOwner");
    uint256 constant FILM_MAX_SUPPLY = 10_000_000_042 ether;

    function setUp() external {
        deployer = new DeployFILMVesting();
        (filmVesting, helperConfig) = deployer.run();
        (address filmTokenAddress) = helperConfig.activeNetworkConfig();
        handler = new Handler(filmVesting, filmToken);
        targetContract(address(handler));

        // For local tests
        filmToken = MockFilmToken(filmTokenAddress);
        vm.prank(FILM_TOKEN_OWNER);
        filmToken.mint(FILM_VESTING_OWNER, FILM_MAX_SUPPLY);

        // For fork tests:
        // filmToken = FILMChain(filmTokenAddress);
        // vm.prank(REAL_FILM_OWNER);
        // filmToken.transfer(FILM_VESTING_OWNER, FILM_MAX_SUPPLY / 2);

        // bytes4[] memory selectors = new bytes4[](2);
        // selectors[0] = Handler.addVestingSchedule.selector;
        // selectors[1] = Handler.increaseAllocation.selector;
        // targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_VestingContractFilmBalanceEqualsSumOfUsersLockedTokens() external {
        address[] memory beneficiaries = filmVesting.getBeneficiaries();
        uint256 sumOfUsersBalances;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            (, uint256 lockedAmount, uint256 releasedAmount) = filmVesting.getVestingSchedule(beneficiaries[i]);
            sumOfUsersBalances += (lockedAmount - releasedAmount);
        }
        assertEq(filmToken.balanceOf(address(filmVesting)), sumOfUsersBalances);
    }

    function invariant_TotalFilmLockedGreaterOrEqualFilmReleased() external view {
        address[] memory beneficiaries = filmVesting.getBeneficiaries();
        uint256 totalLockedAmount;
        uint256 totalReleasedAmount;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            (, uint256 lockedAmount, uint256 releasedAmount) = filmVesting.getVestingSchedule(beneficiaries[i]);
            totalLockedAmount += lockedAmount;
            totalReleasedAmount += releasedAmount;
        }
        assert(totalLockedAmount >= totalReleasedAmount);
    }

    function invariant_gettersDontRevert() external view {
        address[] memory beneficiaries = filmVesting.getBeneficiaries();
        for (uint256 i; i < beneficiaries.length; i++) {
            (, uint256 lockedAmount,) = filmVesting.getVestingSchedule(beneficiaries[i]);
            uint256 releasableAmount = filmVesting.getReleasableAmount(beneficiaries[i]);
            assert(lockedAmount > 0);
            assert(releasableAmount <= lockedAmount);
        }
    }
}
