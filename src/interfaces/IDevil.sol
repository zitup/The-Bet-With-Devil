// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BetStatus, Bet} from "../types/Bet.sol";

interface IDevil {
    /// @notice The underlying token of the bet
    /// @return The token address
    function token() external view returns (address);

    /// @notice The info of a bet of an address
    /// @param key The key of the bet
    /// @return amount The amount to deposit
    /// @return long True if the direction of the bet is long, otherwise false
    /// @return entryPrice Entry price of the underlying token
    /// @return startTime The start timestamp of the bet
    /// @return daysOfDuration The days of duration of the bet
    /// @return status The status of the bet
    function bets(
        bytes32 key
    )
        external
        view
        returns (
            uint128 amount,
            bool long,
            uint256 entryPrice,
            uint256 startTime,
            uint8 daysOfDuration,
            BetStatus status
        );

    /// @notice The discount of the sell order
    /// @param key The key of the sell order
    /// @return discount of the sell order
    function discount(bytes32 key) external view returns (uint16 discount);

    /// @notice Sign the bet wiht Devil
    /// @param recipient The address for which the bet will be created (Is there anyone you love VERY MUCH?)
    /// @param amount The amount to deposit
    /// @param long True if the direction of the bet is long, otherwise false
    /// @param acceptablePrice The acceptable token price for the bet, decimals 18
    /// @param daysOfDuration The days of duration of the bet
    function signTheBet(
        address recipient,
        uint128 amount,
        bool long,
        uint256 acceptablePrice,
        uint8 daysOfDuration
    ) external;

    /// @notice Bear the loss or enjoy the profit
    /// @param amount The deposit token amount of the bet
    /// @param entryPrice The entry token price of the bet
    /// @param long True if the direction of the bet is long, otherwise false
    /// @param startTime The start timestamp of the bet
    /// @param daysOfDuration The days of duration of the bet
    function bearTheBet(
        uint128 amount,
        uint256 entryPrice,
        bool long,
        uint256 startTime,
        uint8 daysOfDuration
    ) external;

    /// @notice Set a discount for a bet and wait for a destined person to buy it
    /// @param amount The deposit token amount of the bet
    /// @param entryPrice The entry token price of the bet
    /// @param long True if the direction of the bet is long, otherwise false
    /// @param daysOfDuration The days of duration of the bet
    /// @param discount The discount number (x%)
    function sendTheBetToTheDestinedPerson(
        uint128 amount,
        bool long,
        uint256 entryPrice,
        uint8 daysOfDuration,
        uint16 discount
    ) external;

    /// @notice But a bet at a discount
    /// @param owner Current owner of the bet
    /// @param amount The deposit token amount of the bet
    /// @param entryPrice The entry token price of the bet
    /// @param long True if the direction of the bet is long, otherwise false
    /// @param daysOfDuration The days of duration of the bet
    /// @param discount The discount number (x%)
    /// @param recipient The address for which the bet will be transferred
    function receiveTheBet(
        address owner,
        uint128 amount,
        bool long,
        uint256 entryPrice,
        uint8 daysOfDuration,
        uint16 discount,
        address recipient
    ) external;
}
