// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Account.sol";
import "./ContractRegistry.sol";

/**
 * @title Reputation contract for calculating user reputation scores
 * @dev This contract calculates user reputation scores based on various factors.
 */

contract Reputation {
    ContractRegistry public registry;

    uint256 private constant REPUTATION_SCALE = 100;
    uint256 private constant TRADE_VOLUME_WEIGHT = 30;
    uint256 private constant ACTIVE_OFFERS_WEIGHT = 20;
    uint256 private constant TRADE_COUNT_WEIGHT = 20;
    uint256 private constant COMPLETION_RATE_WEIGHT = 15;
    uint256 private constant RATING_WEIGHT = 10;
    uint256 private constant ENDORSEMENT_WEIGHT = 5;

    constructor(address _registryAddress) {
        require(
            _registryAddress != address(0),
            "Invalid ContractRegistry address"
        );
        registry = ContractRegistry(_registryAddress);
    }

    /**
     * @dev Calculates the reputation score for a user
     * @param _user The address of the user
     * @return The calculated reputation score
     */

    function calculateReputation(address _user) public view returns (uint256) {
        (, Account.UserStats memory stats) = Account(registry.accountAddress())
            .getUserInfo(_user);

        uint256 tradeVolumeScore = stats.userTotalTradeVolume *
            TRADE_VOLUME_WEIGHT;
        uint256 activeOffersScore = stats.userTotalTradesInitiated *
            ACTIVE_OFFERS_WEIGHT;
        uint256 tradeCountScore = stats.userTotalTradesCompleted *
            TRADE_COUNT_WEIGHT;

        uint256 completionRate = (stats.userTotalTradesCompleted * 100) /
            (
                stats.userTotalTradesAccepted == 0
                    ? 1
                    : stats.userTotalTradesAccepted
            );
        uint256 completionRateScore = (completionRate *
            COMPLETION_RATE_WEIGHT) / 100;

        uint256 ratingScore = stats.userReputationScore * RATING_WEIGHT;
        uint256 endorsementScore = stats.userEndorsementsReceived *
            ENDORSEMENT_WEIGHT;

        uint256 totalScore = tradeVolumeScore +
            activeOffersScore +
            tradeCountScore +
            completionRateScore +
            ratingScore +
            endorsementScore;

        uint256 reputationScore = totalScore / REPUTATION_SCALE;

        // Apply decay factor to reduce the importance of older trades
        uint256 decayFactor = calculateDecayFactor(
            stats.userLastCompletedTradeDate
        );
        reputationScore = (reputationScore * decayFactor) / 100;

        return reputationScore;
    }

    /**
     * @dev Calculates the decay factor based on the time since the last completed trade
     * @param _lastTradeTimestamp The timestamp of the last completed trade
     * @return The calculated decay factor
     */

    function calculateDecayFactor(
        uint256 _lastTradeTimestamp
    ) private view returns (uint256) {
        if (_lastTradeTimestamp == 0) {
            return 100;
        }

        uint256 timeSinceLastTrade = block.timestamp - _lastTradeTimestamp;

        if (timeSinceLastTrade > 365 days) {
            return 50;
        } else if (timeSinceLastTrade > 180 days) {
            return 75;
        } else {
            return 100;
        }
    }
}
