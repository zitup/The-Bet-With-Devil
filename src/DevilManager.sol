// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BetStatus, Bet} from "./types/Bet.sol";
import {IDevil} from "./interfaces/IDevil.sol";

contract DevilManager is ERC721 {
    /// @notice The hash of Devil contract code
    bytes32 internal constant DEVIL_INIT_CODE_HASH = 0x00;

    /// @notice The token ID bet data
    mapping(uint256 => Bet) public bets;

    /// @notice The next token id
    uint256 public nextId = 1;

    event Minted(uint256 indexed tokenId, address indexed owner, uint128 amount, uint256 price);
    event Burned(uint256 indexed tokenId, address indexed owner, uint128 amount, uint128 paid);
    event SetDiscount(uint256 indexed tokenId, uint16 discount);

    modifier isAuthorizedForToken(uint256 tokenId) {
        address owner = _ownerOf(tokenId);
        require(_isAuthorized(owner, address(this), tokenId), "Not approved");
        _;
    }

    modifier isOwnerOf(uint256 tokenId) {
        require(_ownerOf(tokenId) == msg.sender, "Sender is not owner");
        _;
    }

    constructor() ERC721("Devil Mark", "DEVIL-BET") {}

    function mint(
        address token,
        uint8 ratio,
        address recipient,
        uint128 amount,
        bool long,
        uint256 acceptablePrice,
        uint8 daysOfDuration
    ) public {
        address devil = computeAddress(token, ratio);

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        Bet memory bet = IDevil(devil).signTheBet(address(this), amount, long, acceptablePrice, daysOfDuration);

        bets[nextId] = bet;
        uint256 tokenId = nextId;

        address checkedRecipient = recipient == address(0) ? msg.sender : recipient;
        _mint(checkedRecipient, nextId);
        nextId += 1;

        emit Minted(tokenId, checkedRecipient, amount, bet.entryPrice);
    }

    function burn(uint256 tokenId, address token, uint8 ratio) public isOwnerOf(tokenId) {
        address devil = computeAddress(token, ratio);

        Bet memory bet = bets[tokenId];

        (uint128 amount, bool long, uint256 entryPrice, uint256 startTime, uint8 daysOfDuration) = (
            bet.amount,
            bet.long,
            bet.entryPrice,
            bet.startTime,
            bet.daysOfDuration
        );

        uint128 paid = IDevil(devil).bearTheBet(amount, entryPrice, long, startTime, daysOfDuration);

        delete bets[tokenId];

        IERC20(token).transfer(msg.sender, paid);
        _burn(tokenId);

        emit Burned(tokenId, msg.sender, amount, paid);
    }

    function setDiscount(uint256 tokenId, address token, uint8 ratio, uint16 discount) public isOwnerOf(tokenId) {
        address devil = computeAddress(token, ratio);

        Bet memory bet = bets[tokenId];
        (uint128 amount, bool long, uint256 entryPrice, uint256 startTime, uint8 daysOfDuration) = (
            bet.amount,
            bet.long,
            bet.entryPrice,
            bet.startTime,
            bet.daysOfDuration
        );

        IDevil(devil).sendTheBetToTheDestinedPerson(amount, entryPrice, long, startTime, daysOfDuration, discount);

        emit SetDiscount(tokenId, discount);
    }

    function buyBet(
        uint256 tokenId,
        address token,
        uint8 ratio,
        uint16 discount,
        address recipient
    ) public isAuthorizedForToken(tokenId) {
        address devil = computeAddress(token, ratio);

        Bet memory bet = bets[tokenId];
        (uint128 amount, bool long, uint256 entryPrice, uint256 startTime, uint8 daysOfDuration) = (
            bet.amount,
            bet.long,
            bet.entryPrice,
            bet.startTime,
            bet.daysOfDuration
        );

        address owner = _ownerOf(tokenId);
        IERC20(token).transferFrom(msg.sender, address(this), (amount * discount) / 100);
        IDevil(devil).receiveTheBet(
            owner,
            amount,
            entryPrice,
            long,
            startTime,
            daysOfDuration,
            discount,
            address(this)
        );

        address checkedRecipient = recipient == address(0) ? msg.sender : recipient;
        transferFrom(owner, checkedRecipient, tokenId);
    }

    function computeAddress(address token, uint8 ratio) internal view returns (address devil) {
        devil = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(this),
                            keccak256(abi.encode(token, ratio)),
                            DEVIL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    receive() external payable {}
}
