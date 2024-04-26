// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FILMVesting} from "../../src/FILMVesting.sol";
// import {FILMChain} from "../../src/FILMChain.sol"; // For fork tests
import {MockFilmToken} from "../../test/mocks/MockFilmToken.sol";
import {DeployFILMVesting} from "../../script/DeployFILMVesting.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract FILMVestingTest is Test {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    FILMVesting filmVesting;
    // FILMChain filmToken; // For fork tests
    MockFilmToken filmToken;
    HelperConfig helperConfig;
    address FILM_TOKEN_OWNER = makeAddr("filmOwner");
    address REAL_FILM_OWNER = 0x25f82b92B5888374E06E106edC8a262932c7d55C;
    address FILM_VESTING_OWNER = makeAddr("vestingOwner");
    address BENEFICIARY = address(0x1);
    uint256 constant FILM_MAX_SUPPLY = 10_000_000_042 ether;
    uint256 public VESTING_START_DATE; // Placeholder (01/04/2025), set this to the actual date
    uint256 constant FILM_AMOUNT_TO_LOCK = 1000 ether;
    uint256 constant BULK_ADD_NUM = 10;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokensVested(address beneficiary, uint256 amount);
    event VestingScheduleAdded(address beneficiary, uint256 amount, FILMVesting.VestingType vestingType);
    event VestingScheduleAddedInBulk(uint256 amountOfBeneficiaries);
    event AllocationIncreased(address beneficiary, uint256 totalAllocation);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error FILMVesting__ZeroAddressIsInvalidBeneficiary();
    error FILMVesting__CannotAddSoFewTokensToVestingSchedule();
    error FILMVesting__VestingPeriodAlreadyStarted();
    error FILMVesting__NotEnoughFilmAllowanceForVestingContract();
    error FILMVesting__VestingScheduleAlreadyExists();
    error FILMVesting__FilmDepositFailed();
    error FILMVesting__VestingPeriodNotStartedYet();
    error FILMVesting__NoTokensDueForRelease();
    error FILMVesting__BulkVestingArraysDontMatch();
    error FILMVesting__CannotIncreaseAllocationBeforeCreatingSchedule();

    function setUp() public {
        DeployFILMVesting deployFilmVesting = new DeployFILMVesting();
        (filmVesting, helperConfig) = deployFilmVesting.run();
        address filmTokenAddress = helperConfig.activeNetworkConfig();
        // For local tests
        filmToken = MockFilmToken(filmTokenAddress);
        vm.prank(FILM_TOKEN_OWNER);
        filmToken.mint(FILM_VESTING_OWNER, FILM_MAX_SUPPLY);

        // For fork tests:
        // filmToken = FILMChain(filmTokenAddress);
        // vm.prank(REAL_FILM_OWNER);
        // filmToken.transfer(FILM_VESTING_OWNER, FILM_MAX_SUPPLY / 2);

        VESTING_START_DATE = filmVesting.i_vestingStartDate();
    }

    /*//////////////////////////////////////////////////////////////
                       ADD VESTING SCHEDULE TESTS
    //////////////////////////////////////////////////////////////*/

    function testVestingScheduleCreated() external {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        vm.expectEmit(true, true, true, false);
        emit VestingScheduleAdded(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();

        (FILMVesting.VestingType vestingType, uint256 totalAmount, uint256 amountReleased) =
            filmVesting.getVestingSchedule(BENEFICIARY);

        assertEq(uint256(vestingType), uint256(FILMVesting.VestingType.Type1));
        assertEq(totalAmount, FILM_AMOUNT_TO_LOCK);
        assertEq(amountReleased, 0);
    }

    function testFilmTokensReceivedOnScheduleCreation() external {
        uint256 filmBalanceStart = filmToken.balanceOf(address(filmVesting));

        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();

        uint256 filmBalanceEnd = filmToken.balanceOf(address(filmVesting));

        assertEq(FILM_AMOUNT_TO_LOCK, filmBalanceEnd - filmBalanceStart);
    }

    function testCannotAddScheduleToZeroAddress() external {
        vm.startPrank(FILM_VESTING_OWNER);
        // No approval here, since it fails for the zero address
        vm.expectRevert(FILMVesting__ZeroAddressIsInvalidBeneficiary.selector);
        filmVesting.addVestingSchedule(address(0), FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();
    }

    function testCannotAddZeroTokensToVestingSchedule() external {
        uint256 amount = 0;
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), amount);
        vm.expectRevert(FILMVesting__CannotAddSoFewTokensToVestingSchedule.selector);
        filmVesting.addVestingSchedule(BENEFICIARY, amount, FILMVesting.VestingType.Type1);
        vm.stopPrank();
    }

    function testCannotAddTokensToContractAfterVestingStarted() external {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        vm.warp(VESTING_START_DATE + 1 seconds);
        vm.expectRevert(FILMVesting__VestingPeriodAlreadyStarted.selector);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();
    }

    function testCannotCreateScheduletWithoutSufficientApproval() external {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK - 1);
        vm.expectRevert(FILMVesting__NotEnoughFilmAllowanceForVestingContract.selector);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();
    }

    function testCannotCreateAddScheduleTwice() external {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK / 2, FILMVesting.VestingType.Type1);
        vm.expectRevert(FILMVesting__VestingScheduleAlreadyExists.selector);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK / 2, FILMVesting.VestingType.Type1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                       INCREASE ALLOCATION TESTS
    //////////////////////////////////////////////////////////////*/
    function testScheduleAllocationIncreased() external {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), 2 * FILM_AMOUNT_TO_LOCK);
        vm.expectEmit(true, true, true, false);
        emit VestingScheduleAdded(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.expectEmit(true, true, false, false);
        emit AllocationIncreased(BENEFICIARY, FILM_AMOUNT_TO_LOCK);
        filmVesting.increaseAllocation(BENEFICIARY, FILM_AMOUNT_TO_LOCK);
        vm.stopPrank();

        (FILMVesting.VestingType vestingType, uint256 totalAmount, uint256 amountReleased) =
            filmVesting.getVestingSchedule(BENEFICIARY);

        assertEq(uint256(vestingType), uint256(FILMVesting.VestingType.Type1));
        assertEq(totalAmount, 2 * FILM_AMOUNT_TO_LOCK);
        assertEq(amountReleased, 0);
    }

    function testFilmTokensReceivedOnAllocationIncrease() external {
        uint256 filmBalanceStart = filmToken.balanceOf(address(filmVesting));

        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), 2 * FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        uint256 filmBalanceInc = filmToken.balanceOf(address(filmVesting));
        filmVesting.increaseAllocation(BENEFICIARY, FILM_AMOUNT_TO_LOCK);
        vm.stopPrank();

        uint256 filmBalanceEnd = filmToken.balanceOf(address(filmVesting));

        assertEq(FILM_AMOUNT_TO_LOCK, filmBalanceEnd - filmBalanceInc);
        assertEq(FILM_AMOUNT_TO_LOCK, filmBalanceInc - filmBalanceStart);
        assertEq(2 * FILM_AMOUNT_TO_LOCK, filmBalanceEnd - filmBalanceStart);
    }

    function testCannotIncreaseAllocationToZeroAddress() external {
        vm.startPrank(FILM_VESTING_OWNER);
        // No approval here, since it fails for the zero address
        vm.expectRevert(FILMVesting__ZeroAddressIsInvalidBeneficiary.selector);
        filmVesting.increaseAllocation(address(0), FILM_AMOUNT_TO_LOCK);
        vm.stopPrank();
    }

    function testCannotIncreaseAllocationWithZeroTokens() external {
        uint256 amount = 0;
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.expectRevert(FILMVesting__CannotAddSoFewTokensToVestingSchedule.selector);
        filmVesting.increaseAllocation(BENEFICIARY, amount);
        vm.stopPrank();
    }

    function testCannotIncreaseAllocationAfterVestingStarted() external {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), 2 * FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.warp(VESTING_START_DATE + 1 seconds);
        vm.expectRevert(FILMVesting__VestingPeriodAlreadyStarted.selector);
        filmVesting.increaseAllocation(BENEFICIARY, FILM_AMOUNT_TO_LOCK);
        vm.stopPrank();
    }

    function testCannotIncreaseAllocationWithoutSufficientApproval() external {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), 2 * FILM_AMOUNT_TO_LOCK - 1);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.expectRevert(FILMVesting__NotEnoughFilmAllowanceForVestingContract.selector);
        filmVesting.increaseAllocation(BENEFICIARY, FILM_AMOUNT_TO_LOCK);
        vm.stopPrank();
    }

    function testCannotIncreaseBeforeCreatingSchedule() external {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), 2 * FILM_AMOUNT_TO_LOCK - 1);
        vm.expectRevert(FILMVesting__CannotIncreaseAllocationBeforeCreatingSchedule.selector);
        filmVesting.increaseAllocation(BENEFICIARY, FILM_AMOUNT_TO_LOCK);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                           RELEASE FILM TESTS
    //////////////////////////////////////////////////////////////*/

    function testReleaseType1AmountReleasedIncreases() public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();

        vm.warp(VESTING_START_DATE + 3 * 30 days); // Move to the first quarter
        vm.expectEmit(true, true, false, false);
        emit TokensVested(BENEFICIARY, FILM_AMOUNT_TO_LOCK / 4);
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ1 = filmToken.balanceOf(BENEFICIARY);
        assertEq(releasedAmountQ1, FILM_AMOUNT_TO_LOCK / 4); // 25% of the total FILM_AMOUNT_TO_LOCK should be released

        vm.warp(VESTING_START_DATE + 6 * 30 days); // Move to the first half
        vm.expectEmit(true, true, false, false);
        emit TokensVested(BENEFICIARY, FILM_AMOUNT_TO_LOCK / 2);
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ2 = filmToken.balanceOf(BENEFICIARY);
        assertEq(releasedAmountQ2, FILM_AMOUNT_TO_LOCK / 2); // 50% of the total amount should be released

        vm.warp(VESTING_START_DATE + 9 * 30 days); // Move to the third quarter
        vm.expectEmit(true, true, false, false);
        emit TokensVested(BENEFICIARY, 3 * FILM_AMOUNT_TO_LOCK / 4);
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ3 = filmToken.balanceOf(BENEFICIARY);
        assertEq(releasedAmountQ3, 3 * FILM_AMOUNT_TO_LOCK / 4); // 75% of the total amount should be released

        vm.warp(VESTING_START_DATE + 12 * 30 days); // Move to the whole year
        vm.expectEmit(true, true, false, false);
        emit TokensVested(BENEFICIARY, FILM_AMOUNT_TO_LOCK);
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ4 = filmToken.balanceOf(BENEFICIARY);
        assertEq(releasedAmountQ4, FILM_AMOUNT_TO_LOCK); // 100% of the total amount should be released
    }

    function testReleaseType1ContractBalanceDecreases() public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();

        vm.warp(VESTING_START_DATE + 3 * 30 days); // Move to the first quarter
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ1 = filmToken.balanceOf(BENEFICIARY);
        uint256 balanceAfterQ1Release = filmToken.balanceOf(address(filmVesting));
        assertEq(FILM_AMOUNT_TO_LOCK - releasedAmountQ1, balanceAfterQ1Release); // 25% of the total amount should be released
        assertEq(balanceAfterQ1Release, 3 * FILM_AMOUNT_TO_LOCK / 4);

        vm.warp(VESTING_START_DATE + 6 * 30 days); // Move to the first half
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ2 = filmToken.balanceOf(BENEFICIARY);
        uint256 balanceAfterQ2Release = filmToken.balanceOf(address(filmVesting));
        assertEq(FILM_AMOUNT_TO_LOCK - releasedAmountQ2, balanceAfterQ2Release); // 50% of the total amount should be released
        assertEq(balanceAfterQ2Release, FILM_AMOUNT_TO_LOCK / 2);

        vm.warp(VESTING_START_DATE + 9 * 30 days); // Move to the third quarter
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ3 = filmToken.balanceOf(BENEFICIARY);
        uint256 balanceAfterQ3Release = filmToken.balanceOf(address(filmVesting));
        assertEq(FILM_AMOUNT_TO_LOCK - releasedAmountQ3, balanceAfterQ3Release); // 75% of the total amount should be released
        assertEq(balanceAfterQ3Release, FILM_AMOUNT_TO_LOCK / 4);

        vm.warp(VESTING_START_DATE + 12 * 30 days); // Move to the whole year
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ4 = filmToken.balanceOf(BENEFICIARY);
        uint256 balanceAfterQ4Release = filmToken.balanceOf(address(filmVesting));
        assertEq(FILM_AMOUNT_TO_LOCK - releasedAmountQ4, balanceAfterQ4Release); // 100% of the total amount should be released
        assertEq(balanceAfterQ4Release, 0);
    }

    function testReleaseType2AmountReleasedIncreases() public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type2);
        vm.stopPrank();

        vm.warp(VESTING_START_DATE + 3 * 30 days); // Move to the first quarter
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ1 = filmToken.balanceOf(BENEFICIARY);
        assertEq(releasedAmountQ1, FILM_AMOUNT_TO_LOCK / 2); // 50% of the total amount should be released

        vm.warp(VESTING_START_DATE + 6 * 30 days); // Move to the first half
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ4 = filmToken.balanceOf(BENEFICIARY);
        assertEq(releasedAmountQ4, FILM_AMOUNT_TO_LOCK); // 100% of the total amount should be released
    }

    function testReleaseType2ContractBalanceDecreases() public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type2);
        vm.stopPrank();

        vm.warp(VESTING_START_DATE + 3 * 30 days); // Move to the first quarter
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ1 = filmToken.balanceOf(BENEFICIARY);
        uint256 balanceAfterQ1Release = filmToken.balanceOf(address(filmVesting));
        assertEq(FILM_AMOUNT_TO_LOCK - releasedAmountQ1, balanceAfterQ1Release); // 50% of the total amount should be released
        assertEq(balanceAfterQ1Release, FILM_AMOUNT_TO_LOCK / 2);

        vm.warp(VESTING_START_DATE + 6 * 30 days); // Move to the first half
        filmVesting.release(BENEFICIARY);
        uint256 releasedAmountQ2 = filmToken.balanceOf(BENEFICIARY);
        uint256 balanceAfterQ2Release = filmToken.balanceOf(address(filmVesting));
        assertEq(FILM_AMOUNT_TO_LOCK - releasedAmountQ2, balanceAfterQ2Release); // 100% of the total amount should be released
        assertEq(balanceAfterQ2Release, 0);
    }

    function testReleaseRevertsIfVestingNotStarted() public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();

        vm.warp(VESTING_START_DATE - 1 seconds);
        vm.expectRevert(FILMVesting__VestingPeriodNotStartedYet.selector);
        filmVesting.release(BENEFICIARY);
    }

    function testReleaseRevertsIfFirstReleaseDateNotReached() public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();

        vm.warp(VESTING_START_DATE);
        vm.expectRevert(FILMVesting__NoTokensDueForRelease.selector);
        filmVesting.release(BENEFICIARY);
    }

    function testReleaseRevertsIfAvailableTokensAlreadyReleasedType1() public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type1);
        vm.stopPrank();

        vm.warp(VESTING_START_DATE + 3 * 30 days); // Move to the first quarter
        filmVesting.release(BENEFICIARY);
        vm.expectRevert(FILMVesting__NoTokensDueForRelease.selector);
        filmVesting.release(BENEFICIARY);

        vm.warp(VESTING_START_DATE + 6 * 30 days); // Move to the first half
        filmVesting.release(BENEFICIARY);
        vm.expectRevert(FILMVesting__NoTokensDueForRelease.selector);
        filmVesting.release(BENEFICIARY);

        vm.warp(VESTING_START_DATE + 9 * 30 days); // Move to the third half
        filmVesting.release(BENEFICIARY);
        vm.expectRevert(FILMVesting__NoTokensDueForRelease.selector);
        filmVesting.release(BENEFICIARY);

        vm.warp(VESTING_START_DATE + 12 * 30 days); // Move to the first year
        filmVesting.release(BENEFICIARY);
        vm.expectRevert(FILMVesting__NoTokensDueForRelease.selector);
        filmVesting.release(BENEFICIARY);
    }

    function testReleaseRevertsIfAvailableTokensAlreadyReleasedType2() public {
        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), FILM_AMOUNT_TO_LOCK);
        filmVesting.addVestingSchedule(BENEFICIARY, FILM_AMOUNT_TO_LOCK, FILMVesting.VestingType.Type2);
        vm.stopPrank();

        vm.warp(VESTING_START_DATE + 3 * 30 days); // Move to the first quarter
        filmVesting.release(BENEFICIARY);
        vm.expectRevert(FILMVesting__NoTokensDueForRelease.selector);
        filmVesting.release(BENEFICIARY);

        vm.warp(VESTING_START_DATE + 6 * 30 days); // Move to the first half
        filmVesting.release(BENEFICIARY);
        vm.expectRevert(FILMVesting__NoTokensDueForRelease.selector);
        filmVesting.release(BENEFICIARY);
    }

    /*//////////////////////////////////////////////////////////////
                    ADD BULK VESTING SCHEDULES TESTS
    //////////////////////////////////////////////////////////////*/

    function testVestingSchedulesCreatedBulk() external {
        address[] memory beneficiaries = new address[](BULK_ADD_NUM);
        uint256[] memory amounts = new uint256[](BULK_ADD_NUM);
        uint256 totalAmount;
        for (uint256 i; i < BULK_ADD_NUM; i++) {
            beneficiaries[i] = address(uint160(1 + i));
            amounts[i] = FILM_AMOUNT_TO_LOCK + i * 100 ether;
            totalAmount += amounts[i];
        }

        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), totalAmount);
        for (uint256 i; i < BULK_ADD_NUM; i++) {
            vm.expectEmit(true, true, true, false);
            emit VestingScheduleAdded(beneficiaries[i], amounts[i], FILMVesting.VestingType.Type1);
        }
        vm.expectEmit(true, false, false, false);
        emit VestingScheduleAddedInBulk(beneficiaries.length);
        filmVesting.addBulkVestingSchedules(beneficiaries, amounts, FILMVesting.VestingType.Type1);
        vm.stopPrank();

        for (uint256 i; i < BULK_ADD_NUM; i++) {
            (FILMVesting.VestingType vestingType, uint256 lockedAmount, uint256 amountReleased) =
                filmVesting.getVestingSchedule(beneficiaries[i]);
            assertEq(uint256(vestingType), uint256(FILMVesting.VestingType.Type1));
            assertEq(lockedAmount, amounts[i]);
            assertEq(amountReleased, 0);
        }
    }

    function testFilmTokensReceivedOnBulkScheduleCreations() external {
        address[] memory beneficiaries = new address[](BULK_ADD_NUM);
        uint256[] memory amounts = new uint256[](BULK_ADD_NUM);
        uint256 totalAmount;
        uint256 filmBalanceStart = filmToken.balanceOf(address(filmVesting));

        for (uint256 i; i < BULK_ADD_NUM; i++) {
            beneficiaries[i] = address(uint160(1 + i));
            amounts[i] = FILM_AMOUNT_TO_LOCK + i * 100 ether;
            totalAmount += amounts[i];
        }

        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), totalAmount);
        for (uint256 i; i < BULK_ADD_NUM; i++) {
            vm.expectEmit(true, true, true, false);
            emit VestingScheduleAdded(beneficiaries[i], amounts[i], FILMVesting.VestingType.Type1);
        }
        vm.expectEmit(true, false, false, false);
        emit VestingScheduleAddedInBulk(beneficiaries.length);
        filmVesting.addBulkVestingSchedules(beneficiaries, amounts, FILMVesting.VestingType.Type1);
        vm.stopPrank();

        uint256 filmBalanceEnd = filmToken.balanceOf(address(filmVesting));

        assertEq(totalAmount, filmBalanceEnd - filmBalanceStart);
    }

    function testBulkAdditionArraysMustHaveSameLength() external {
        address[] memory beneficiaries = new address[](BULK_ADD_NUM);
        uint256[] memory amounts = new uint256[](BULK_ADD_NUM - 1);
        uint256 totalAmount;

        for (uint256 i; i < BULK_ADD_NUM - 1; i++) {
            beneficiaries[i] = address(uint160(1 + i));
            amounts[i] = FILM_AMOUNT_TO_LOCK + i * 100 ether;
            totalAmount += amounts[i];
        }

        vm.startPrank(FILM_VESTING_OWNER);
        filmToken.approve(address(filmVesting), totalAmount);
        vm.expectRevert(FILMVesting__BulkVestingArraysDontMatch.selector);
        filmVesting.addBulkVestingSchedules(beneficiaries, amounts, FILMVesting.VestingType.Type1);
        vm.stopPrank();
    }
}
