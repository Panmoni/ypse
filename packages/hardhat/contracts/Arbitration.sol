// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ContractRegistry.sol";
import "./Trade.sol";
import "./Escrow.sol";
import "./Account.sol";

/**
 * @title Arbitration contract for resolving trade disputes
 * @dev This contract handles the creation and resolution of trade disputes.
 */

contract Arbitration {
    address public admin;
    ContractRegistry public registry;

    enum DisputeStatus {
        Pending,
        Resolved,
        Canceled
    }

    struct DisputeDetails {
        uint256 tradeId;
        DisputeStatus status;
        uint256 disputeTimestamp;
        uint256 resolveTimestamp;
        bool resolvedInFavorOfMaker;
    }

    uint256 public resolutionTimelock = 1 days; // Timelock period for dispute resolution

    uint256 public disputeCount;
    mapping(uint256 => DisputeDetails) public disputes;
    mapping(uint256 => uint256) public tradeDisputeIds;
    mapping(uint256 => string[]) public disputeEvidence;

    event DisputeCreated(uint256 indexed tradeId, uint256 disputeId);
    event DisputeResolved(
        uint256 indexed tradeId,
        uint256 disputeId,
        bool resolvedInFavorOfMaker
    );

    event DisputeResolutionInitiated(
        uint256 indexed tradeId,
        uint256 disputeId,
        uint256 resolutionTimestamp
    );
    event DisputeEvidenceSubmitted(
        uint256 indexed tradeId,
        uint256 disputeId,
        address indexed submitter,
        string evidence
    );
    event DisputeResolutionTimelockExpired(
        uint256 indexed tradeId,
        uint256 disputeId
    );
    event DisputeResolutionCanceled(uint256 indexed tradeId, uint256 disputeId);
    event ResolutionTimelockUpdated(uint256 newTimelock);

    constructor(address _admin, address _registryAddress) {
        require(_admin != address(0), "Invalid admin address");
        require(
            _registryAddress != address(0),
            "Invalid ContractRegistry address"
        );

        admin = _admin;
        registry = ContractRegistry(_registryAddress);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyTradeContract() {
        require(
            msg.sender == registry.tradeAddress(),
            "Only Trade contract can perform this action"
        );
        _;
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

    modifier disputeExists(uint256 _disputeId) {
        require(
            _disputeId > 0 && _disputeId <= disputeCount,
            "Dispute does not exist"
        );
        _;
    }

    modifier disputeNotResolved(uint256 _disputeId) {
        require(
            disputes[_disputeId].status == DisputeStatus.Pending,
            "Dispute is already resolved"
        );
        _;
    }

    modifier tradeExists(uint256 _tradeId) {
        (uint256 offerId, , , , , , , , , , , ) = Trade(registry.tradeAddress())
            .getTradeDetails(_tradeId);
        require(offerId != 0, "Trade does not exist");
        _;
    }

    /**
     * @dev Allows a trade party to submit evidence for a dispute
     * @param _tradeId The ID of the trade
     * @param _evidence The evidence or arguments submitted by the trade party
     * @notice Only the trade parties (maker or taker) can submit evidence
     * @notice The dispute must be in pending status
     */
    function submitEvidence(
        uint256 _tradeId,
        string memory _evidence
    ) public tradeExists(_tradeId) onlyTradeParty(_tradeId) {
        uint256 disputeId = tradeDisputeIds[_tradeId];
        require(disputeId != 0, "No dispute found for the trade");
        require(
            disputes[disputeId].status == DisputeStatus.Pending,
            "Dispute is not in pending status"
        );

        disputeEvidence[disputeId].push(_evidence);
        emit DisputeEvidenceSubmitted(
            _tradeId,
            disputeId,
            msg.sender,
            _evidence
        );
    }

    /**
     * @dev Initiates the dispute resolution process with a timelock
     * @param _disputeId The ID of the dispute
     * @param _resolveInFavorOfMaker Whether the dispute is resolved in favor of the maker
     * @notice Only an admin can call this function
     * @notice The dispute must be in pending status
     */
    function initiateDisputeResolution(
        uint256 _disputeId,
        bool _resolveInFavorOfMaker
    )
        public
        onlyAdmin
        disputeExists(_disputeId)
        disputeNotResolved(_disputeId)
    {
        disputes[_disputeId].resolveTimestamp =
            block.timestamp +
            resolutionTimelock;
        disputes[_disputeId].resolvedInFavorOfMaker = _resolveInFavorOfMaker;

        emit DisputeResolutionInitiated(
            disputes[_disputeId].tradeId,
            _disputeId,
            disputes[_disputeId].resolveTimestamp
        );
    }

    /**
     * @dev Resolves a dispute after the timelock period has expired
     * @param _disputeId The ID of the dispute
     * @notice Only an admin can call this function
     * @notice The dispute must be in pending status and the timelock period must have expired
     */
    function resolveDisputeAfterTimelock(
        uint256 _disputeId
    )
        public
        onlyAdmin
        disputeExists(_disputeId)
        disputeNotResolved(_disputeId)
    {
        require(
            block.timestamp >= disputes[_disputeId].resolveTimestamp,
            "Timelock period has not expired"
        );

        uint256 tradeId = disputes[_disputeId].tradeId;
        bool resolvedInFavorOfMaker = disputes[_disputeId]
            .resolvedInFavorOfMaker;

        disputes[_disputeId].status = DisputeStatus.Resolved;

        (, address maker, , , , , , , , , , ) = Trade(registry.tradeAddress())
            .getTradeDetails(tradeId);
        (, address taker, , , , , , , , , , ) = Trade(registry.tradeAddress())
            .getTradeDetails(tradeId);

        if (resolvedInFavorOfMaker) {
            Escrow(registry.escrowAddress()).releaseCrypto(
                tradeId,
                payable(maker)
            );
            Trade(registry.tradeAddress()).updateTradeStatusFromArbitration(
                tradeId,
                Trade.TradeStatus.Finalized
            );
        } else {
            Escrow(registry.escrowAddress()).refundCrypto(tradeId);
            Trade(registry.tradeAddress()).updateTradeStatusFromArbitration(
                tradeId,
                Trade.TradeStatus.Cancelled
            );
        }

        emit DisputeResolved(tradeId, _disputeId, resolvedInFavorOfMaker);
        emit DisputeResolutionTimelockExpired(tradeId, _disputeId);

        // Update the disputes initiated for both maker and taker
        Account(registry.accountAddress()).updateDisputesInitiated(maker);
        Account(registry.accountAddress()).updateDisputesInitiated(taker);

        // Update the disputes lost based on the dispute outcome
        if (resolvedInFavorOfMaker) {
            Account(registry.accountAddress()).updateDisputesLost(taker);
        } else {
            Account(registry.accountAddress()).updateDisputesLost(maker);
        }
    }

    /**
     * @dev Cancels a dispute resolution
     * @param _disputeId The ID of the dispute
     * @notice Only an admin can call this function
     * @notice The dispute must be in pending status
     */
    function cancelDisputeResolution(
        uint256 _disputeId
    )
        public
        onlyAdmin
        disputeExists(_disputeId)
        disputeNotResolved(_disputeId)
    {
        uint256 tradeId = disputes[_disputeId].tradeId;
        disputes[_disputeId].status = DisputeStatus.Canceled;

        emit DisputeResolutionCanceled(tradeId, _disputeId);
    }

    /**
     * @dev Retrieves the details of a dispute
     * @param _disputeId The ID of the dispute
     * @return tradeId The ID of the trade associated with the dispute
     * @return status The status of the dispute
     * @return disputeTimestamp The timestamp when the dispute was created
     * @return resolveTimestamp The timestamp when the dispute is set to be resolved
     * @return resolvedInFavorOfMaker Whether the dispute is resolved in favor of the maker
     */
    function getDisputeDetails(
        uint256 _disputeId
    )
        public
        view
        disputeExists(_disputeId)
        returns (
            uint256 tradeId,
            DisputeStatus status,
            uint256 disputeTimestamp,
            uint256 resolveTimestamp,
            bool resolvedInFavorOfMaker
        )
    {
        DisputeDetails memory dispute = disputes[_disputeId];
        tradeId = dispute.tradeId;
        status = dispute.status;
        disputeTimestamp = dispute.disputeTimestamp;
        resolveTimestamp = dispute.resolveTimestamp;
        resolvedInFavorOfMaker = dispute.resolvedInFavorOfMaker;
    }

    /**
     * @dev Updates the resolution timelock period
     * @param _newTimelock The new timelock period in seconds
     * @notice Only an admin can call this function
     */
    function updateResolutionTimelock(uint256 _newTimelock) public onlyAdmin {
        resolutionTimelock = _newTimelock;
        emit ResolutionTimelockUpdated(_newTimelock);
    }

    /**
     * @dev Creates a new dispute for a trade
     * @param _tradeId The ID of the trade
     * @notice Only the Trade contract can call this function
     * @notice The trade must be in disputed status
     */

    function handleDispute(
        uint256 _tradeId
    ) public onlyTradeContract tradeExists(_tradeId) {
        (, , , , , , , , Trade.TradeStatus tradeStatus, , , ) = Trade(
            registry.tradeAddress()
        ).getTradeDetails(_tradeId);
        require(
            tradeStatus == Trade.TradeStatus.Disputed,
            "Trade is not in disputed status"
        );

        disputeCount++;
        disputes[disputeCount] = DisputeDetails(
            _tradeId,
            DisputeStatus.Pending,
            block.timestamp,
            0,
            false
        );
        tradeDisputeIds[_tradeId] = disputeCount;

        emit DisputeCreated(_tradeId, disputeCount);
    }

    /**
     * @dev Resolves a dispute
     * @param _disputeId The ID of the dispute
     * @param _resolveInFavorOfMaker Whether the dispute is resolved in favor of the maker
     * @notice Only an admin can call this function
     * @notice The dispute must be in pending status and not already initiated for resolution
     */
    function resolveDispute(
        uint256 _disputeId,
        bool _resolveInFavorOfMaker
    )
        public
        onlyAdmin
        disputeExists(_disputeId)
        disputeNotResolved(_disputeId)
    {
        require(
            disputes[_disputeId].resolveTimestamp == 0,
            "Dispute resolution already initiated"
        );

        uint256 tradeId = disputes[_disputeId].tradeId;
        (, address maker, , , , , , , , , , ) = Trade(registry.tradeAddress())
            .getTradeDetails(tradeId);

        disputes[_disputeId].status = DisputeStatus.Resolved;
        disputes[_disputeId].resolveTimestamp = block.timestamp;
        disputes[_disputeId].resolvedInFavorOfMaker = _resolveInFavorOfMaker;

        if (_resolveInFavorOfMaker) {
            Escrow(registry.escrowAddress()).releaseCrypto(
                tradeId,
                payable(maker)
            );
        } else {
            Escrow(registry.escrowAddress()).refundCrypto(tradeId);
        }

        emit DisputeResolved(tradeId, _disputeId, _resolveInFavorOfMaker);
    }

    /**
     * @dev Checks if a dispute is resolved for a trade
     * @param _tradeId The ID of the trade
     * @return Whether the dispute is resolved
     */
    function isDisputeResolved(
        uint256 _tradeId
    ) public view tradeExists(_tradeId) returns (bool) {
        uint256 disputeId = tradeDisputeIds[_tradeId];
        return
            disputeId != 0 &&
            disputes[disputeId].status == DisputeStatus.Resolved;
    }

    /**
     * @dev Retrieves the outcome of a dispute for a trade
     * @param _tradeId The ID of the trade
     * @return Whether the dispute was resolved in favor of the maker
     */
    function getDisputeOutcome(
        uint256 _tradeId
    ) public view tradeExists(_tradeId) returns (bool) {
        uint256 disputeId = tradeDisputeIds[_tradeId];
        require(disputeId != 0, "No dispute found for the trade");
        return disputes[disputeId].resolvedInFavorOfMaker;
    }
}
