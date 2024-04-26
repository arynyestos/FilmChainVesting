// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FILMVesting is Ownable {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    enum VestingType {
        Type1, // 25% every quarter in four quarters
        Type2 // 50% every quarter in two quarters

    }

    struct VestingSchedule {
        VestingType vestingType; // 1 or 2
        uint256 totalAmount; // full locked amount that will be vested
        uint256 amountReleased; // amount that has already been released (when vesting has started)
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public filmToken;
    uint256 public immutable i_vestingStartDate;
    mapping(address => VestingSchedule) public vestingSchedules;
    address[] private s_beneficiaries; // Beneficiaries whose tokens have been locked and will be vested
    uint256 constant MIN_LOCK_AMOUNT = 4; // At least 4E-18 FILM tokens to release in 4 quarters

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokensVested(address beneficiary, uint256 amount);
    event VestingScheduleAdded(address beneficiary, uint256 amount, VestingType vestingType);
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
    error FILMVesting__FilmReleaseFailed();
    error FILMVesting__BulkVestingArraysDontMatch();
    error FILMVesting__CannotIncreaseAllocationBeforeCreatingSchedule();

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(IERC20 _filmToken, uint256 vestingStartDate) {
        filmToken = _filmToken;
        i_vestingStartDate = vestingStartDate;
    }

    /**
     *
     * @param beneficiary address that will have its tokens vested
     * @param amount amount of FILM tokens vested
     * @param vestingType type of vesting: 25% in four quarters or 50% in two quarters
     */
    function addVestingSchedule(address beneficiary, uint256 amount, VestingType vestingType) public onlyOwner {
        if (beneficiary == address(0)) revert FILMVesting__ZeroAddressIsInvalidBeneficiary();
        if (amount < MIN_LOCK_AMOUNT) revert FILMVesting__CannotAddSoFewTokensToVestingSchedule();
        if (block.timestamp >= i_vestingStartDate) revert FILMVesting__VestingPeriodAlreadyStarted();
        if (filmToken.allowance(msg.sender, address(this)) < amount) {
            revert FILMVesting__NotEnoughFilmAllowanceForVestingContract();
        }

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount > 0) revert FILMVesting__VestingScheduleAlreadyExists();

        bool depositSuccess = filmToken.transferFrom(msg.sender, address(this), amount);
        if (!depositSuccess) revert FILMVesting__FilmDepositFailed();

        schedule.vestingType = vestingType;
        schedule.totalAmount = amount;

        s_beneficiaries.push(beneficiary);

        emit VestingScheduleAdded(beneficiary, amount, vestingType);
    }

    /**
     *
     * @param beneficiary address gets its FILM allocation increased
     * @param amount amount of extra FILM tokens vested
     */
    function increaseAllocation(address beneficiary, uint256 amount) external onlyOwner {
        if (beneficiary == address(0)) revert FILMVesting__ZeroAddressIsInvalidBeneficiary();
        if (amount < MIN_LOCK_AMOUNT) revert FILMVesting__CannotAddSoFewTokensToVestingSchedule();
        if (block.timestamp >= i_vestingStartDate) revert FILMVesting__VestingPeriodAlreadyStarted();
        if (filmToken.allowance(msg.sender, address(this)) < amount) {
            revert FILMVesting__NotEnoughFilmAllowanceForVestingContract();
        }
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0 && schedule.amountReleased == 0) {
            revert FILMVesting__CannotIncreaseAllocationBeforeCreatingSchedule();
        }

        bool depositSuccess = filmToken.transferFrom(msg.sender, address(this), amount);
        if (!depositSuccess) revert FILMVesting__FilmDepositFailed();
        schedule.totalAmount += amount; // Support for monthly contributions

        emit AllocationIncreased(beneficiary, schedule.totalAmount);
    }

    /**
     *
     * @param beneficiary address that gets its tokens released
     */
    function release(address beneficiary) external {
        if (block.timestamp < i_vestingStartDate) revert FILMVesting__VestingPeriodNotStartedYet();
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        uint256 amountToRelease = calculateReleaseAmount(beneficiary);

        if (amountToRelease == 0) revert FILMVesting__NoTokensDueForRelease();

        schedule.amountReleased += amountToRelease;
        bool releaseSuccess = filmToken.transfer(beneficiary, amountToRelease);
        if (!releaseSuccess) revert FILMVesting__FilmReleaseFailed();

        emit TokensVested(beneficiary, amountToRelease);
    }

    /**
     *
     * @param beneficiary address whose tokens due for release are calculated
     */
    function calculateReleaseAmount(address beneficiary) private view returns (uint256) {
        if (block.timestamp < i_vestingStartDate) return 0;

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0 || schedule.totalAmount == schedule.amountReleased) return 0;

        uint256 timeElapsed = block.timestamp - i_vestingStartDate;
        uint256 totalQuartersElapsed = timeElapsed / (3 * 30 days);
        uint256 totalUnlockedAmount;

        if (totalQuartersElapsed >= 1) {
            if (schedule.vestingType == VestingType.Type1) {
                totalUnlockedAmount = totalQuartersElapsed * schedule.totalAmount * 25 / 100;
            } else if (schedule.vestingType == VestingType.Type2) {
                totalUnlockedAmount = totalQuartersElapsed * schedule.totalAmount * 50 / 100;
            }
        } else {
            return 0;
        }

        if (totalUnlockedAmount > schedule.totalAmount) {
            totalUnlockedAmount = schedule.totalAmount;
        }

        return totalUnlockedAmount - schedule.amountReleased;
    }

    /**
     *
     * @param beneficiaries the addresses whose FILM toikens are vested
     * @param amounts the amount of FILM
     * @param vestingType the type of vesting
     * @notice vestingType will be the same for all batched beneficiaries to avoid possible mixups
     */
    function addBulkVestingSchedules(address[] memory beneficiaries, uint256[] memory amounts, VestingType vestingType)
        external
        onlyOwner
    {
        if (beneficiaries.length != amounts.length) revert FILMVesting__BulkVestingArraysDontMatch();
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            addVestingSchedule(beneficiaries[i], amounts[i], vestingType);
        }

        emit VestingScheduleAddedInBulk(beneficiaries.length);
    }

    /**
     *
     * @param beneficiary address whose vesting schedule is queried
     */
    function getVestingSchedule(address beneficiary) external view returns (VestingType, uint256, uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        return (schedule.vestingType, schedule.totalAmount, schedule.amountReleased);
    }

    /**
     *
     * @param beneficiary address whose tokens due for release are queried
     */
    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        return calculateReleaseAmount(beneficiary);
    }

    function getBeneficiaries() external view returns (address[] memory) {
        return s_beneficiaries;
    }
}
