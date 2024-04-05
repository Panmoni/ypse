// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Account.sol";
import "./ContractRegistry.sol";

/**
 * @title Offer contract for managing trade offers
 * @dev This contract handles offer creation, updates, and maintains offer statistics.
 */

contract Offer {
    address public owner;
    bool public paused;

    ContractRegistry public registry;

    enum OfferStatus {
        Active,
        Paused,
        Withdrawn
    }

    struct OfferDetails {
        address offerOwner;
        uint256 offerTotalTradesAccepted;
        uint256 offerTotalTradesCompleted;
        uint256 offerDisputesInvolved;
        uint256 offerDisputesLost;
        uint256 offerAverageTradeVolume;
        uint256 offerMinTradeAmount;
        uint256 offerMaxTradeAmount;
        string offerFiatCurrency;
        OfferStatus offerStatus;
        uint256 offerCreatedTime;
        uint256 offerLastUpdatedTime;
        bool offerBuyingCrypto;
        string offerCountry;
        string offerPaymentMethod;
        string offerTerms;
        int256 offerRate;
        string offerTitle;
    }

    uint256 public offerCount;

    mapping(uint256 => OfferDetails) public offers;
    mapping(address => uint256[]) public userOffers;
    mapping(uint256 => mapping(uint256 => bool)) public offerDisputeCounted;
    mapping(address => mapping(bytes32 => bool)) public offerParametersUsed;

    // event TradeContractSet(
    //     address indexed previousAddress,
    //     address indexed newAddress
    // );
    event OfferCreated(
        uint256 indexed offerId,
        address indexed offerOwner,
        uint256 minTradeAmount,
        uint256 maxTradeAmount,
        string fiatCurrency,
        OfferStatus status
    );
    event OfferUpdated(
        uint256 indexed offerId,
        uint256 minTradeAmount,
        uint256 maxTradeAmount,
        OfferStatus status
    );
    event OfferPaused(uint256 indexed offerId);
    event OfferActivated(uint256 indexed offerId);
    event OfferWithdrawn(uint256 indexed offerId);
    event OfferMinMaxTradeAmountsChanged(
        uint256 indexed offerId,
        uint256 minAmount,
        uint256 maxAmount
    );
    event OfferStatsUpdated(uint256 indexed offerId);
    event OfferTradeAccepted(uint256 indexed offerId);
    event OfferTradeCompleted(uint256 indexed offerId, uint256 tradeVolume);
    event OfferDisputeInvolved(uint256 indexed offerId, uint256 disputeId);
    event OfferDisputeLost(uint256 indexed offerId, uint256 disputeId);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event ContractPaused();
    event ContractUnpaused();

    constructor(address _registryAddress) {
        require(
            _registryAddress != address(0),
            "Invalid ContractRegistry address"
        );
        owner = msg.sender;
        registry = ContractRegistry(_registryAddress);
    }

    // Or enable owner to change it?
    // function setTradeContract(address _tradeContract) public onlyOwner {
    //     require(_tradeContract != address(0), "Invalid Trade contract address");
    //     emit TradeContractSet(tradeContract, _tradeContract);
    //     tradeContract = _tradeContract;
    // }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can perform this action"
        );
        _;
    }

    modifier onlyTradeContract() {
        require(
            msg.sender == registry.tradeAddress(),
            "Only Trade contract can perform this action"
        );
        _;
    }

    modifier offerExists(uint256 _offerId) {
        require(_offerId > 0 && _offerId <= offerCount, "Offer does not exist");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    /**
     * @dev Retrieves the list of offers created by a user
     * @param _user The address of the user
     * @return The array of offer IDs created by the user
     */

    function getUserOffers(
        address _user
    ) public view returns (uint256[] memory) {
        return userOffers[_user];
    }

    /**
     * @dev Creates a new offer
     * @param _minTradeAmount The minimum trade amount for the offer
     * @param _maxTradeAmount The maximum trade amount for the offer
     * @param _fiatCurrency The fiat currency for the offer
     */

    function offerCreate(
        uint256 _minTradeAmount,
        uint256 _maxTradeAmount,
        string memory _fiatCurrency,
        bool _buyingCrypto,
        string memory _country,
        string memory _paymentMethod,
        string memory _terms,
        int256 _rate,
        string memory _title
    ) public whenNotPaused {
        require(
            _minTradeAmount <= _maxTradeAmount,
            "Invalid trade amount range"
        );
        require(
            bytes(_fiatCurrency).length > 0,
            "Fiat currency cannot be empty"
        );
        require(bytes(_country).length > 0, "Country cannot be empty");
        require(
            bytes(_paymentMethod).length > 0,
            "Payment method cannot be empty"
        );
        require(bytes(_terms).length > 0, "Terms cannot be empty");
        require(bytes(_title).length > 0, "Title cannot be empty");

        bytes32 offerHash = keccak256(
            abi.encodePacked(
                msg.sender,
                _minTradeAmount,
                _maxTradeAmount,
                _fiatCurrency,
                _buyingCrypto,
                _country,
                _paymentMethod,
                _terms,
                _rate,
                _title
            )
        );
        require(
            !offerParametersUsed[msg.sender][offerHash],
            "Duplicate offer parameters"
        );
        offerParametersUsed[msg.sender][offerHash] = true;

        offerCount++;
        offers[offerCount] = OfferDetails(
            msg.sender,
            0,
            0,
            0,
            0,
            0,
            _minTradeAmount,
            _maxTradeAmount,
            _fiatCurrency,
            OfferStatus.Active,
            block.timestamp,
            block.timestamp,
            _buyingCrypto,
            _country,
            _paymentMethod,
            _terms,
            _rate,
            _title
        );

        userOffers[msg.sender].push(offerCount);
        emit OfferCreated(
            offerCount,
            msg.sender,
            _minTradeAmount,
            _maxTradeAmount,
            _fiatCurrency,
            OfferStatus.Active
        );
    }

    /**
     * @dev Updates an existing offer
     * @param _offerId The ID of the offer to update
     * @param _minTradeAmount The updated minimum trade amount for the offer
     * @param _maxTradeAmount The updated maximum trade amount for the offer
     * @param _status The updated status of the offer
     */

    function offerUpdateOffer(
        uint256 _offerId,
        uint256 _minTradeAmount,
        uint256 _maxTradeAmount,
        OfferStatus _status,
        bool _buyingCrypto,
        string memory _country,
        string memory _paymentMethod,
        string memory _terms,
        int256 _rate,
        string memory _title
    ) public offerExists(_offerId) {
        require(
            offers[_offerId].offerOwner == msg.sender,
            "Only offer owner can update the offer"
        );
        require(
            _minTradeAmount <= _maxTradeAmount,
            "Invalid trade amount range"
        );

        OfferDetails storage offer = offers[_offerId];

        if (
            offer.offerMinTradeAmount != _minTradeAmount ||
            offer.offerMaxTradeAmount != _maxTradeAmount
        ) {
            offer.offerMinTradeAmount = _minTradeAmount;
            offer.offerMaxTradeAmount = _maxTradeAmount;
            emit OfferMinMaxTradeAmountsChanged(
                _offerId,
                _minTradeAmount,
                _maxTradeAmount
            );
        }

        offer.offerLastUpdatedTime = block.timestamp;
        offer.offerBuyingCrypto = _buyingCrypto;
        offer.offerCountry = _country;
        offer.offerPaymentMethod = _paymentMethod;
        offer.offerTerms = _terms;
        offer.offerRate = _rate;
        offer.offerTitle = _title;

        emit OfferUpdated(_offerId, _minTradeAmount, _maxTradeAmount, _status);

        if (offer.offerStatus != _status) {
            offer.offerStatus = _status;
            if (_status == OfferStatus.Paused) {
                emit OfferPaused(_offerId);
            } else if (_status == OfferStatus.Active) {
                emit OfferActivated(_offerId);
            } else if (_status == OfferStatus.Withdrawn) {
                emit OfferWithdrawn(_offerId);
            }
        }
    }

    /**
     * @dev Retrieves the details of an offer
     * @param _offerId The ID of the offer
     * @return The offer details
     */

    function getOfferDetails(
        uint256 _offerId
    )
        public
        view
        offerExists(_offerId)
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            string memory,
            bool,
            uint256,
            uint256,
            bool,
            string memory,
            string memory,
            string memory,
            int256,
            string memory
        )
    {
        OfferDetails memory offer = offers[_offerId];
        return (
            offer.offerOwner,
            offer.offerTotalTradesAccepted,
            offer.offerTotalTradesCompleted,
            offer.offerDisputesInvolved,
            offer.offerDisputesLost,
            offer.offerAverageTradeVolume,
            offer.offerMinTradeAmount,
            offer.offerMaxTradeAmount,
            offer.offerFiatCurrency,
            offer.offerStatus == OfferStatus.Active,
            offer.offerCreatedTime,
            offer.offerLastUpdatedTime,
            offer.offerBuyingCrypto,
            offer.offerCountry,
            offer.offerPaymentMethod,
            offer.offerTerms,
            offer.offerRate,
            offer.offerTitle
        );
    }

    /**
     * @dev Retrieves the counts of accepted, completed, disputed, and lost trades for all offers
     * @return acceptedCount The total number of accepted trades
     * @return completedCount The total number of completed trades
     * @return disputedCount The total number of disputed trades
     * @return lostCount The total number of lost trades
     */

    // Opportunity to save on gas here by storing counts separately
    function getOfferCounts()
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 acceptedCount = 0;
        uint256 completedCount = 0;
        uint256 disputedCount = 0;
        uint256 lostCount = 0;

        for (uint256 i = 1; i <= offerCount; i++) {
            acceptedCount += offers[i].offerTotalTradesAccepted;
            completedCount += offers[i].offerTotalTradesCompleted;
            disputedCount += offers[i].offerDisputesInvolved;
            lostCount += offers[i].offerDisputesLost;
        }

        return (acceptedCount, completedCount, disputedCount, lostCount);
    }

    /**
     * @dev Updates the statistics of an offer based on trade events
     * @param _offerId The ID of the offer
     * @param _tradeVolume The trade volume
     * @param _accepted Whether the trade was accepted
     * @param _completed Whether the trade was completed
     * @param _disputed Whether the trade was disputed
     * @param _lost Whether the trade was lost
     * @param _disputeId The ID of the dispute
     */

    function updateOfferStats(
        uint256 _offerId,
        uint256 _tradeVolume,
        bool _accepted,
        bool _completed,
        bool _disputed,
        bool _lost,
        uint256 _disputeId
    ) public offerExists(_offerId) whenNotPaused onlyTradeContract {
        require(_disputeId > 0, "Invalid dispute ID");

        OfferDetails storage offer = offers[_offerId];
        bool statsUpdated = false;

        if (_accepted) {
            offer.offerTotalTradesAccepted++;
            emit OfferTradeAccepted(_offerId);
            statsUpdated = true;
        }
        if (_completed) {
            offer.offerTotalTradesCompleted++;
            emit OfferTradeCompleted(_offerId, _tradeVolume);
            if (offer.offerTotalTradesCompleted > 1) {
                offer.offerAverageTradeVolume =
                    (offer.offerAverageTradeVolume *
                        (offer.offerTotalTradesCompleted - 1) +
                        _tradeVolume) /
                    offer.offerTotalTradesCompleted;
            } else {
                offer.offerAverageTradeVolume = _tradeVolume;
            }
            statsUpdated = true;
        }
        if (_disputed && !offerDisputeCounted[_offerId][_disputeId]) {
            offer.offerDisputesInvolved++;
            offerDisputeCounted[_offerId][_disputeId] = true;
            emit OfferDisputeInvolved(_offerId, _disputeId);
            statsUpdated = true;
        }
        if (_lost && !offerDisputeCounted[_offerId][_disputeId]) {
            offer.offerDisputesLost++;
            offerDisputeCounted[_offerId][_disputeId] = true;
            emit OfferDisputeLost(_offerId, _disputeId);
            statsUpdated = true;
        }

        if (statsUpdated) {
            emit OfferStatsUpdated(_offerId);
        }
    }

    /**
     * @dev Pauses the contract, preventing offer creation and updates
     */

    function pauseContract() public onlyOwner {
        require(!paused, "Contract is already paused");
        paused = true;
        emit ContractPaused();
    }

    /**
     * @dev Unpauses the contract, allowing offer creation and updates
     */

    function unpauseContract() public onlyOwner {
        require(paused, "Contract is not paused");
        paused = false;
        emit ContractUnpaused();
    }

    /**
     * @dev Transfers ownership of the contract to a new owner
     * @param _newOwner The address of the new owner
     */

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}
