// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

enum BetStatus {
    CREATED,
    FINISHED
}

struct Bet {
    uint256 amount;
    // direction, long or short
    bool long;
    uint256 entryPrice;
    uint256 startTime;
    // days of duration of the bet
    uint8 daysOfDuration;
    BetStatus status;
}
