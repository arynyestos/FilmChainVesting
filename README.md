# FILMVesting Contract

## Overview
The `FILMVesting` contract is designed to manage the vesting of FILM tokens for beneficiaries over specific periods according to predefined vesting schedules. This contract provides mechanisms to add vesting schedules for beneficiaries, release vested tokens, and manage the vesting process securely. Although the contract is named after the FILM token, because this was a job done for the [FilmChain](https://filmchain.xyz/) project, the vesting contract may work with any ERC-20 token.

### Features
- **Flexible Vesting Schedules:** Supports two types of vesting schedules:
  - **Type1**: Releases 25% of the tokens every quarter over four quarters.
  - **Type2**: Releases 50% of the tokens every quarter over two quarters.
- **Secure Token Handling:** Uses ERC20 tokens for vesting, ensuring compatibility with a wide range of digital assets.
- **Owner Controls**: Only the owner (typically the deploying entity) can add or modify vesting schedules, ensuring administrative control.
- **Transparency**: Allows querying of vesting schedules and releasable amounts for any beneficiary.

## Contract Details

### State Variables
- `filmToken`: ERC20 token which is being vested.
- `i_vestingStartDate`: Immutable start date from which vesting schedules begin.
- `vestingSchedules`: Mapping from beneficiary addresses to their respective vesting schedules.
- `s_beneficiaries`: List of all beneficiaries who have tokens vested.

### Functions
- `addVestingSchedule`: Adds a new vesting schedule for a beneficiary.
- `increaseAllocation`: Increases the token amount for an existing beneficiary's vesting schedule.
- `release`: Releases the vested tokens to the beneficiary if the vesting period conditions are met.
- `getVestingSchedule`: Returns the vesting schedule details for a beneficiary.
- `getReleasableAmount`: Computes the amount of tokens that can be released to a beneficiary at the current time.

### Events
- `TokensVested`: Emitted when tokens are released to a beneficiary.
- `VestingScheduleAdded`: Emitted when a new vesting schedule is added.
- `VestingScheduleAddedInBulk`: Emitted when multiple vesting schedules are added simultaneously.
- `AllocationIncreased`: Emitted when the token allocation for a beneficiary's vesting schedule is increased.

## Deployment

### Requirements
- An ERC20 token address that the vesting contract will interact with.
- A start date for the vesting schedules.

### Deploying with Remix
1. Open [Remix IDE](https://remix.ethereum.org).
2. Load the `FILMVesting.sol` file into Remix.
3. Compile the contract using the Solidity compiler.
4. Go to the "Deploy & Run Transactions" panel.
5. Make sure the environment is set to "Injected Web3" if you are using MetaMask.
6. In the "Deploy" section, enter the ERC20 token contract address and the desired start date for `i_vestingStartDate` (UNIX timestamp of the date vesting should start) in the constructor parameters.
7. Click "Deploy".

Bear in mind that contracts deployed on Remix will need to be verified afterwards. 

### Deploying and verifying with a Script
- If using a script like `DeployFILMVesting.sol`, ensure you adjust parameters for the token address and the vesting start date.
- Example script usage (adjust paths and parameters as necessary):
  ```shell
  forge script script/DeployFILMVesting.s.sol --rpc-url $BSC_TESTNET_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier-url $BSC_SCAN_API_URL --etherscan-api-key $BSC_SCAN_API_KEY
  ```
Ensure that all environment variables ($BSC_TESTNET_RPC_URL, $PRIVATE_KEY, $BSC_SCAN_API_URL, $BSC_SCAN_API_KEY) are defined in your environment or .env file. These variables should include your RPC endpoint, private key, and BSCScan API credentials necessary for deployment and verification.

### Conclusion
The FILMVesting contract offers a robust solution for managing the phased release of ERC20 tokens according to predefined schedules. Ensure you test thoroughly in a testnet environment before deploying to the mainnet to confirm all functionalities work as expected.