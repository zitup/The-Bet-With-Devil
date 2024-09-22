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
    /// @notice Thrown when the L2 sequencer is unactive
    error L2SequencerUnavailable();
    /// @notice Thrown when the feed price exceed the acceptable price
    error ExceedAcceptablePrice(uint256 price);
    /// @notice Thrown when the discount is invalid
    error InvalidDiscount();
    /// @notice Thrown when the discount doesn't match. Avoid changing discount before the swap tx
    error UnmatchedDiscount();
    error InvalidBet();

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
    event SendTheBetToTheDestinedPerson(bytes32 indexed key, uint16 indexed _discount);
    event ReceiveTheBet(address indexed recipient, address indexed owner, bytes32 key, uint256 discountAmount);

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
    ) public nonReentrant whenNotPaused returns (Bet memory bet) {
        require(amount > 0 && recipient != address(0));
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
        bet = Bet(amount, long, price, block.timestamp, daysOfDuration, BetStatus.CREATED);
        bets[keccak256(abi.encodePacked(recipient, amount, long, price, block.timestamp, daysOfDuration))] = bet;

        // // transfer token
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        emit SignedTheBet(msg.sender, recipient, amount, long, price, block.timestamp, daysOfDuration);
    }

    /// @inheritdoc IDevil
    function bearTheBet(
        uint128 amount,
        uint256 entryPrice,
        bool long,
        uint256 startTime,
        uint8 daysOfDuration
    ) public nonReentrant whenNotPaused returns (uint128 paid) {
        // check bet
        bytes32 key = keccak256(abi.encodePacked(msg.sender, amount, long, entryPrice, startTime, daysOfDuration));
        Bet memory bet = bets[key];
        if (bet.status == BetStatus.CREATED) {
            // compare price
            uint256 price = getChainlinkPrice();
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
        } else {
            revert InvalidBet();
        }
    }

    /// @inheritdoc IDevil
    function sendTheBetToTheDestinedPerson(
        uint128 amount,
        uint256 entryPrice,
        bool long,
        uint256 startTime,
        uint8 daysOfDuration,
        uint16 _discount
    ) public nonReentrant whenNotPaused {
        if (_discount == 0) {
            revert InvalidDiscount();
        }
        bytes32 key = keccak256(abi.encodePacked(msg.sender, amount, long, entryPrice, startTime, daysOfDuration));
        if (bets[key].status != BetStatus.CREATED) {
            revert InvalidBet();
        }
        discount[key] = _discount;
        emit SendTheBetToTheDestinedPerson(key, _discount);
    }

    /// @inheritdoc IDevil
    function receiveTheBet(
        address owner,
        uint128 amount,
        uint256 entryPrice,
        bool long,
        uint256 startTime,
        uint8 daysOfDuration,
        uint16 _discount,
        address recipient
    ) public nonReentrant whenNotPaused {
        require(_discount > 0 && recipient != address(0));
        // check if there is a selling bet with the given info, check if _discount match, avoid mev attack
        bytes32 key = keccak256(abi.encodePacked(owner, amount, long, entryPrice, startTime, daysOfDuration));
        Bet memory bet = bets[key];
        if (bet.status != BetStatus.CREATED) {
            revert InvalidBet();
        }
        if (discount[key] != _discount) {
            revert UnmatchedDiscount();
        }

        // update bet
        delete bets[key];
        bets[keccak256(abi.encodePacked(recipient, amount, long, entryPrice, startTime, daysOfDuration))] = bet;

        // transfer token
        uint256 discountAmount = (amount * _discount) / 100;
        IERC20(token).transferFrom(msg.sender, owner, discountAmount);

        emit ReceiveTheBet(recipient, owner, key, discountAmount);
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
