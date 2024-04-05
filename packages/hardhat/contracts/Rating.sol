// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Trade.sol";
import "./Offer.sol";
import "./Account.sol";
import "./ContractRegistry.sol";

/**
 * @title Rating contract for managing trade ratings
 * @dev This contract handles the rating of trades by trade parties.
 */
contract Rating {
    ContractRegistry public registry;

    struct RatingDetails {
        uint256 tradeId;
        uint256 offerId;
        address raterId;
        address rateeId;
        uint256 rateStars;
        string rateString;
        uint256 rateTimestamp;
    }

    uint256 public ratingCount;
    mapping(uint256 => RatingDetails) public ratings;
    mapping(uint256 => mapping(address => bool)) public tradeRatings;

    event TradeRated(
        uint256 indexed tradeId,
        uint256 indexed offerId,
        address indexed raterId,
        address rateeId,
        uint256 rateStars,
        string rateString
    );

    event UserReputationUpdated(address indexed user, uint256 newReputation);

    constructor(address _registryAddress) {
        require(
            _registryAddress != address(0),
            "Invalid ContractRegistry address"
        );
        registry = ContractRegistry(_registryAddress);
    }

    modifier onlyTradeParty(uint256 _tradeId) {
        (, address maker, , , , , , , , , , ) = Trade(registry.tradeAddress())
            .getTradeDetails(_tradeId);
        (, address taker, , , , , , , , , , ) = Trade(registry.tradeAddress())
            .getTradeDetails(_tradeId);
        require(
            msg.sender == maker || msg.sender == taker,
            "Only trade parties can perform this action"
        );
        _;
    }

    modifier tradeExists(uint256 _tradeId) {
        (uint256 offerId, , , , , , , , , , , ) = Trade(registry.tradeAddress())
            .getTradeDetails(_tradeId);
        require(offerId != 0, "Trade does not exist");
        _;
    }

    modifier tradeFinalized(uint256 _tradeId) {
        (, , , , , , , , Trade.TradeStatus tradeStatus, , , ) = Trade(
            registry.tradeAddress()
        ).getTradeDetails(_tradeId);
        require(
            tradeStatus == Trade.TradeStatus.Finalized,
            "Trade is not in finalized status"
        );
        _;
    }

    modifier notAlreadyRated(uint256 _tradeId) {
        require(
            !tradeRatings[_tradeId][msg.sender],
            "Trade has already been rated by the user"
        );
        _;
    }

    /**
     * @dev Rates a trade
     * @param _tradeId The ID of the trade
     * @param _rateStars The rating stars given (1-5)
     * @param _rateString The rating comment
     * @notice Only the trade parties (maker or taker) can rate the trade
     * @notice The trade must be in finalized status
     * @notice The user can only rate a trade once
     */
    function rateTrade(
        uint256 _tradeId,
        uint256 _rateStars,
        string memory _rateString
    )
        public
        tradeExists(_tradeId)
        tradeFinalized(_tradeId)
        onlyTradeParty(_tradeId)
        notAlreadyRated(_tradeId)
    {
        require(
            _rateStars >= 1 && _rateStars <= 5,
            "Rating stars must be between 1 and 5"
        );
        require(
            bytes(_rateString).length <= 280,
            "Rating string must not exceed 280 bytes"
        );

        (uint256 offerId, address taker, , , , , , , , , , ) = Trade(
            registry.tradeAddress()
        ).getTradeDetails(_tradeId);
        address rateeId;
        if (msg.sender == taker) {
            (address offerOwner, , , , , , , , , , , , , , , , , ) = Offer(
                registry.offerAddress()
            ).getOfferDetails(offerId);
            rateeId = offerOwner;
        } else {
            rateeId = taker;
        }

        ratingCount++;
        ratings[ratingCount] = RatingDetails(
            _tradeId,
            offerId,
            msg.sender,
            rateeId,
            _rateStars,
            _rateString,
            block.timestamp
        );
        tradeRatings[_tradeId][msg.sender] = true;

        emit TradeRated(
            _tradeId,
            offerId,
            msg.sender,
            rateeId,
            _rateStars,
            _rateString
        );

        // Update user reputation in the Account contract
        uint256 newReputation = Account(registry.accountAddress())
            .userReputationCalc(rateeId);
        emit UserReputationUpdated(rateeId, newReputation);
    }
}
