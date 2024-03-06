// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FILMVesting} from "../../src/FILMVesting.sol";
import {FILMChain} from "../../src/FILMChain.sol"; // For fork tests
import {MockFilmToken} from "../../test/mocks/MockFilmToken.sol";

contract Handler is Test {
    FILMVesting public filmVesting;
    FILMChain filmToken; // For fork tests
    // MockFilmToken filmToken;
    // MockMocProxy public mockMocProxy;
    uint256 constant FILM_MAX_SUPPLY = 10_000_000_042 ether;
    uint256 constant FILM_MIN_LOCK_AMOUNT = 4;
    uint256 constant FILM_MAX_LOCK_AMOUNT = FILM_MAX_SUPPLY / 1000; // for the sake of testing
    uint256 constant VESTING_START_DATE = 1743458400; // Placeholder (01/04/2025), set this to the actual date
    address FILM_VESTING_OWNER = makeAddr("vestingOwner");
    address[] bulkBeneficiaries;
    uint256[] bulkAmounts;

    // constructor(FILMVesting _filmVesting, MockFilmToken _filmToken) {
    constructor(FILMVesting _filmVesting, FILMChain _filmToken) {
        // For fork tests
        filmVesting = _filmVesting;
        filmToken = _filmToken;
    }

    // function addVestingSchedule(address beneficiary, uint256 amount, FILMVesting.VestingType vestingType) public {
    function addVestingSchedule(address beneficiary, uint256 amount, uint256 vestingTypeIndex) public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_MAX_SUPPLY);
        amount = bound(amount, FILM_MIN_LOCK_AMOUNT, FILM_MAX_LOCK_AMOUNT);
        if (beneficiary == address(0)) return;
        (, uint256 lockedAmount,) = filmVesting.getVestingSchedule(beneficiary);
        if (lockedAmount > 0) return;
        FILMVesting.VestingType vestingType = FILMVesting.VestingType(vestingTypeIndex % 2);
        filmVesting.addVestingSchedule(beneficiary, amount, vestingType);
        vm.stopPrank();
    }

    function increaseAllocation(address beneficiary, uint256 amount) public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_MAX_SUPPLY);
        amount = bound(amount, FILM_MIN_LOCK_AMOUNT, FILM_MAX_LOCK_AMOUNT);
        if (beneficiary == address(0)) return;
        (, uint256 lockedAmount,) = filmVesting.getVestingSchedule(beneficiary);
        if (lockedAmount == 0) return;
        filmVesting.increaseAllocation(beneficiary, amount);
        vm.stopPrank();
    }

    function release(address beneficiary) external {
        uint256 releaseableAmount = filmVesting.getReleasableAmount(beneficiary);
        if (releaseableAmount < FILM_MIN_LOCK_AMOUNT) return;
        filmVesting.release(beneficiary);
    }

    function addBulkVestingSchedules(
        address[5] memory beneficiaries, // Fixed length to make tests faster
        uint256[5] memory amounts,
        uint256 vestingTypeIndex
    ) public {
        bulkBeneficiaries = beneficiaries;
        bulkAmounts = amounts;
        if (bulkBeneficiaries.length == 0 || bulkAmounts.length == 0) return;
        console.log("Arrays length: ", bulkBeneficiaries.length);
        uint256 totalBulkAmount;
        for (uint256 i; i < bulkBeneficiaries.length; i++) {
            bulkAmounts[i] = bound(bulkAmounts[i], FILM_MIN_LOCK_AMOUNT, FILM_MAX_LOCK_AMOUNT);
            if (bulkBeneficiaries[i] == address(0)) bulkBeneficiaries[i] = address(uint160(i + 1));
            (, uint256 lockedAmount,) = filmVesting.getVestingSchedule(bulkBeneficiaries[i]);
            if (lockedAmount > 0) bulkBeneficiaries[i] = address(uint160(uint160(bulkBeneficiaries[i]) + 1));
            totalBulkAmount += bulkAmounts[i];
            if (totalBulkAmount > FILM_MAX_SUPPLY) return;
        }
        FILMVesting.VestingType vestingType = FILMVesting.VestingType(vestingTypeIndex % 2);
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_MAX_SUPPLY);
        filmVesting.addBulkVestingSchedules(bulkBeneficiaries, bulkAmounts, vestingType);
        vm.stopPrank();
    }
}
