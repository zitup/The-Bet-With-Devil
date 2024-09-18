// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {BetStatus, Bet} from "./types/Bet.sol";
import {IDevil} from "./interfaces/IDevil.sol";
import {AggregatorV3Interface} from "./interfaces/external/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Devil is IDevil, ReentrancyGuard, Pausable {
    AggregatorV3Interface internal priceFeed;
    /// @notice heart beat duration(seconds) of price feed, according to https://docs.chain.link/data-feeds/price-feeds/addresses
    uint256 public priceFeedHeartbeat;
    /// @notice L2 Sequencer feed, according to https://docs.chain.link/data-feeds/l2-sequencer-feeds
    AggregatorV3Interface immutable sequencer;
    /// @notice L2 Sequencer grace period
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    /// @dev The minimum value of the days of duration
    uint8 public constant MINIMUM_DURATION = 2;
    /// @inheritdoc IDevil
    address public immutable token;
    /// @inheritdoc IDevil
    mapping(bytes32 => Bet) public bets;
    /// @inheritdoc IDevil
    mapping(bytes32 => uint16) public discount;

    /// @notice Reward or punish ratio when winning or losing(x%)
    uint8 public immutable ratio;

    /// @notice Thrown when the days of duration is less then MINIMUM_DURATION
    error InvalidDuration();
    /// @notice Thrown when the feed price is less then or equal 0
    error InvalidFeedPrice(int256 price);
    /// @notice Thrown when the feed price is staled
    error StaledPriceFeed(uint256 timeStamp);
    error L2SequencerUnavailable();
    error ExceedAcceptablePrice(uint256 price);

    event SignedTheBet(
        address sender,
        address indexed owner,
        uint128 amount,
        bool long,
        uint256 entryPrice,
        uint256 startTime,
        uint8 daysOfDuration
    );
    event BearedTheBet(address indexed owner, bytes32 indexed key, uint128 amount, uint128 paid);

    constructor(address _token, address _priceFeed, uint256 _priceFeedHeartbeat, address _sequencer, uint8 _ratio) {
        token = _token;
        priceFeed = AggregatorV3Interface(_priceFeed);
        priceFeedHeartbeat = _priceFeedHeartbeat;
        sequencer = AggregatorV3Interface(_sequencer);
        ratio = _ratio;
    }

    /// @inheritdoc IDevil
    function signTheBet(
        address recipient,
        uint128 amount,
        bool long,
        uint256 acceptablePrice,
        uint8 daysOfDuration
    ) public nonReentrant whenNotPaused {
        // check daysOfDuration
        if (daysOfDuration < MINIMUM_DURATION) {
            revert InvalidDuration();
        }

        // check if match acceptable price
        uint256 price = getChainlinkPrice();
        if (long) {
            if (price > acceptablePrice) {
                revert ExceedAcceptablePrice(price);
            }
        } else {
            if (price < acceptablePrice) {
                revert ExceedAcceptablePrice(price);
            }
        }

        // update state
        Bet memory bet = Bet(amount, long, price, block.timestamp, daysOfDuration, BetStatus.CREATED);
        bets[keccak256(abi.encodePacked(recipient, amount, long, price, block.timestamp, daysOfDuration))] = bet;

        // transfer token
        IERC20(token).transfer(address(this), amount);

        emit SignedTheBet(msg.sender, recipient, amount, long, price, block.timestamp, daysOfDuration);
    }

    /// @inheritdoc IDevil
    function bearTheBet(
        uint128 amount,
        uint256 entryPrice,
        bool long,
        uint256 startTime,
        uint8 daysOfDuration
    ) public nonReentrant whenNotPaused {
        // check bet
        bytes32 key = keccak256(abi.encodePacked(msg.sender, amount, long, entryPrice, startTime, daysOfDuration));
        Bet memory bet = bets[key];
        if (bet.status == BetStatus.CREATED) {
            // compare price
            uint256 price = getChainlinkPrice();
            uint128 paid;
            if ((long && price > entryPrice) || (!long && price < entryPrice)) {
                // win
                paid = (amount * (100 + ratio)) / 100;
            } else {
                // loss
                paid = (amount * (100 - ratio)) / 100;
            }

            // update state
            bets[key].status = BetStatus.FINISHED;

            // transfer token
            IERC20(token).transfer(msg.sender, paid);

            emit BearedTheBet(msg.sender, key, amount, paid);
        }
    }

    /// @inheritdoc IDevil
    function sendTheBetToTheDestinedPerson(
        uint128 amount,
        bool long,
        uint256 entryPrice,
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
        bool long,
        uint256 entryPrice,
        uint8 daysOfDuration,
        uint16 _discount,
        address recipient
    ) public nonReentrant whenNotPaused {
        // 1. check if there is a selling bet by the given info, check _discount if match
        // 2. check the token balance of msg.sender
        // 3. update bet
        // 4. transfer token
    }

    function getChainlinkPrice() public view returns (uint256) {
        if (!isSequencerActive()) {
            revert L2SequencerUnavailable();
        }

        // prettier-ignore
        (
            /* uint80 roundID */,
            int256 _price,
            /*uint startedAt*/,
            uint timeStamp,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        if (_price <= 0) {
            revert InvalidFeedPrice(_price);
        }

        if (block.timestamp - timeStamp > priceFeedHeartbeat) {
            revert StaledPriceFeed(timeStamp);
        }
        uint256 price = uint256(_price);
        // convert the price feed price to the price of 1 unit of the token represented with 18 decimals
        return (price * 10 ** 18) / priceFeed.decimals();
    }

    function isSequencerActive() internal view returns (bool) {
        (, int256 answer, uint256 startedAt, , ) = sequencer.latestRoundData();
        if (block.timestamp - startedAt <= GRACE_PERIOD_TIME || answer == 1) return false;
        return true;
    }
}
