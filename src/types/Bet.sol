// SPDX-License-Identifier: CC-BY-NC-ND
pragma solidity ^0.8.20;

enum BetStatus {
    NULL,
    CREATED,
    FINISHED
}

struct Bet {
    uint128 amount;
    // direction, long or short
    bool long;
    uint256 entryPrice;
    uint256 startTime;
    // days of duration of the bet
    uint8 daysOfDuration;
    BetStatus status;
}
