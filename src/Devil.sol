// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {BetStatus, Bet} from "./types/Bet.sol";
import {IDevil} from "./interfaces/IDevil.sol";

contract Devil is IDevil, ReentrancyGuard, Pausable {
    /// @inheritdoc IDevil
    address public immutable token;
    /// @inheritdoc IDevil
    mapping(bytes32 => Bet) public bet;
    /// @inheritdoc IDevil
    mapping(bytes32 => uint16) public discount;

    constructor(address _token) {
        token = _token;
    }

    /// @inheritdoc IDevil
    function signTheBet(
        address recipient,
        uint128 amount,
        uint128 acceptablePrice,
        bool long,
        uint8 daysOfDuration
    ) public nonReentrant whenNotPaused {}

    /// @inheritdoc IDevil
    function bearTheBet(
        uint128 amount,
        uint128 entryPrice,
        bool long,
        uint8 daysOfDuration
    ) public nonReentrant whenNotPaused {}

    /// @inheritdoc IDevil
    function sendTheBetToTheDestinedPerson(
        uint128 amount,
        uint128 entryPrice,
        bool long,
        uint8 daysOfDuration,
        uint16 _discount
    ) public nonReentrant whenNotPaused {
        // key = keccake256(msg.sender, ...)
        // discount[key] = _discount
    }

    /// @inheritdoc IDevil
    function receiveTheBet(
        address owner,
        uint128 amount,
        uint128 entryPrice,
        bool long,
        uint8 daysOfDuration,
        uint16 _discount,
        address recipient
    ) public nonReentrant whenNotPaused {
        // 1. check if there is a selling bet by the given info, check _discount if match
        // 2. check the token balance of msg.sender
        // 3. update bet
        // 4. transfer token
    }
}
