// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Trade.sol";
import "./Arbitration.sol";
import "./ContractRegistry.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title Escrow contract for handling trade funds
 * @dev This contract manages the locking, releasing, refunding, splitting, and penalizing of funds for trades.
 */

contract Escrow is ReentrancyGuardUpgradeable {
    address public admin;
    ContractRegistry public registry;

    uint256 public platformFeePercentage;
    uint256 public penaltyPercentage;

    struct EscrowDetails {
        uint256 tradeId;
        uint256 amount;
        bool isLocked;
        bool isReleased;
        bool isRefunded;
    }

    mapping(uint256 => EscrowDetails) public escrows;

    event CryptoLocked(uint256 indexed tradeId, uint256 amount);
    event CryptoReleased(uint256 indexed tradeId, uint256 amount);
    event CryptoRefunded(uint256 indexed tradeId, uint256 amount);
    event CryptoSplit(
        uint256 indexed tradeId,
        uint256 amount,
        uint256 splitAmount
    );
    event CryptoPenalized(
        uint256 indexed tradeId,
        uint256 amount,
        uint256 penaltyAmount
    );
    event PlatformFeePaid(uint256 indexed tradeId, uint256 feeAmount);
    event FeePercentagesUpdated(
        uint256 platformFeePercentage,
        uint256 penaltyPercentage
    );
    event EscrowTransferred(
        uint256 indexed sourceTradeId,
        uint256 indexed destTradeId,
        uint256 amount
    );

    constructor(
        address _admin,
        address _registryAddress,
        uint256 _platformFeePercentage,
        uint256 _penaltyPercentage
    ) {
        require(_admin != address(0), "Invalid admin address");
        require(
            _registryAddress != address(0),
            "Invalid ContractRegistry address"
        );
        require(
            _platformFeePercentage <= 1,
            "Platform fee percentage must be between 0 and 1"
        );
        require(
            _penaltyPercentage <= 100,
            "Penalty percentage must be between 0 and 100"
        );

        admin = _admin;
        registry = ContractRegistry(_registryAddress);
        platformFeePercentage = _platformFeePercentage;
        penaltyPercentage = _penaltyPercentage;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only an admin can perform this action");
        _;
    }

    modifier onlyTradeContract() {
        require(
            msg.sender == registry.tradeAddress(),
            "Only the Trade contract can perform this action"
        );
        _;
    }

    modifier onlyArbitrationContract() {
        require(
            msg.sender == registry.arbitrationAddress(),
            "Only the Arbitration contract can perform this action"
        );
        _;
    }

    /**
     * @dev Locks the crypto for a trade
     * @param _tradeId The ID of the trade
     * @param _amount The amount of crypto to lock
     * @notice Only the Trade contract can call this function
     * @notice The crypto must not be already locked for the trade
     */

    function lockCrypto(
        uint256 _tradeId,
        uint256 _amount
    ) public onlyTradeContract {
        require(
            !escrows[_tradeId].isLocked,
            "The crypto is already locked for this trade"
        );

        escrows[_tradeId] = EscrowDetails(
            _tradeId,
            _amount,
            true,
            false,
            false
        );

        emit CryptoLocked(_tradeId, _amount);
    }

    function releaseCrypto(
        uint256 _tradeId,
        address payable _receiver
    ) public nonReentrant onlyTradeContract {
        // Check if the trade escrow is locked and not released or refunded
        require(
            escrows[_tradeId].isLocked,
            "The crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isReleased,
            "The crypto is already released for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "The crypto is already refunded for this trade"
        );

        // Get the escrow amount
        uint256 amount = escrows[_tradeId].amount;

        // Transfer the crypto to the receiver
        _receiver.transfer(amount);

        // Update the escrow balances and state variables accordingly
        escrows[_tradeId].amount = 0;
        escrows[_tradeId].isReleased = true;

        // Emit event for crypto release
        emit CryptoReleased(_tradeId, amount);
    }

    function refundCrypto(
        uint256 _tradeId
    ) public nonReentrant onlyTradeContract {
        // Check if the trade escrow is locked and not released or refunded
        require(escrows[_tradeId].isLocked, "The trade escrow is not locked");
        require(
            !escrows[_tradeId].isReleased,
            "The trade escrow is already released"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "The trade escrow is already refunded"
        );

        // Determine the previous escrow account in the sequence
        uint256 prevTradeId = Trade(registry.tradeAddress())
            .getPreviousTradeInSequence(_tradeId);

        // Check if there is a previous trade in the sequence
        if (prevTradeId != 0) {
            // Transfer the crypto from the current escrow to the previous escrow
            uint256 refundAmount = escrows[_tradeId].amount;
            escrows[_tradeId].amount = 0;
            escrows[prevTradeId].amount += refundAmount;

            // Update the escrow balances and state variables accordingly
            escrows[_tradeId].isLocked = false;
            escrows[_tradeId].isRefunded = true;
            escrows[prevTradeId].isLocked = true;

            // Emit events for crypto refund and escrow transfer
            emit CryptoRefunded(_tradeId, refundAmount);
            emit EscrowTransferred(_tradeId, prevTradeId, refundAmount);
        } else {
            // If there is no previous trade, refund the crypto to the original sender
            uint256 refundAmount = escrows[_tradeId].amount;
            escrows[_tradeId].amount = 0;
            payable(Trade(registry.tradeAddress()).getTradeMaker(_tradeId))
                .transfer(refundAmount);

            // Update the escrow balances and state variables accordingly
            escrows[_tradeId].isLocked = false;
            escrows[_tradeId].isRefunded = true;

            // Emit event for crypto refund
            emit CryptoRefunded(_tradeId, refundAmount);
        }
    }

    /**
     * @dev Splits the crypto and sends a portion to the receiver
     * @param _tradeId The ID of the trade
     * @param _splitAmount The amount of crypto to split
     * @param _receiver The address of the receiver
     * @notice Only an admin can call this function
     * @notice The crypto must be locked for the trade
     * @notice The crypto must not be already released or refunded for the trade
     * @notice The split amount must not exceed the locked amount
     */

    function splitCrypto(
        uint256 _tradeId,
        uint256 _splitAmount,
        address payable _receiver
    ) public nonReentrant onlyAdmin {
        require(
            escrows[_tradeId].isLocked,
            "Crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isReleased,
            "Crypto is already released for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "Crypto is already refunded for this trade"
        );
        require(
            _splitAmount <= escrows[_tradeId].amount,
            "Split amount exceeds the locked amount"
        );

        uint256 remainingAmount = escrows[_tradeId].amount - _splitAmount;

        // Transfer the split amount to the receiver
        _receiver.transfer(_splitAmount);

        // Update the escrow amount
        escrows[_tradeId].amount = remainingAmount;

        emit CryptoSplit(_tradeId, escrows[_tradeId].amount, _splitAmount);
    }

    /**
     * @dev Penalizes the crypto by transferring a portion to the admin
     * @param _tradeId The ID of the trade
     * @notice Only an admin can call this function
     * @notice The crypto must be locked for the trade
     * @notice The crypto must not be already released or refunded for the trade
     */

    function penalizeCrypto(uint256 _tradeId) public nonReentrant onlyAdmin {
        require(
            escrows[_tradeId].isLocked,
            "Crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isReleased,
            "Crypto is already released for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "Crypto is already refunded for this trade"
        );

        uint256 penaltyAmount = (escrows[_tradeId].amount * penaltyPercentage) /
            100;
        uint256 remainingAmount = escrows[_tradeId].amount - penaltyAmount;

        // Transfer the penalty amount to the admin
        payable(admin).transfer(penaltyAmount);

        // Update the escrow amount
        escrows[_tradeId].amount = remainingAmount;

        emit CryptoPenalized(_tradeId, escrows[_tradeId].amount, penaltyAmount);
    }

    /**
     * @dev Pays the platform fee by transferring the fee amount to the admin
     * @param _tradeId The ID of the trade
     * @notice Only an admin can call this function
     * @notice The crypto must be locked for the trade
     * @notice The crypto must not be already released or refunded for the trade
     */

    function payPlatformFee(uint256 _tradeId) public nonReentrant onlyAdmin {
        require(
            escrows[_tradeId].isLocked,
            "Crypto is not locked for this trade"
        );
        require(
            !escrows[_tradeId].isReleased,
            "Crypto is already released for this trade"
        );
        require(
            !escrows[_tradeId].isRefunded,
            "Crypto is already refunded for this trade"
        );

        uint256 feeAmount = calculatePlatformFee(_tradeId);
        uint256 remainingAmount = escrows[_tradeId].amount - feeAmount;

        // Transfer the fee amount to the admin
        payable(admin).transfer(feeAmount);

        // Update the escrow amount
        escrows[_tradeId].amount = remainingAmount;

        emit PlatformFeePaid(_tradeId, feeAmount);
    }

    /**
     * @dev Updates the platform fee and penalty percentages
     * @param _platformFeePercentage The new platform fee percentage
     * @param _penaltyPercentage The new penalty percentage
     * @notice Only an admin can call this function
     * @notice The platform fee percentage must be between 0 and 1
     * @notice The penalty percentage must be between 0 and 100
     */

    function updateFeePercentages(
        uint256 _platformFeePercentage,
        uint256 _penaltyPercentage
    ) public onlyAdmin {
        require(
            _platformFeePercentage <= 1,
            "Platform fee percentage must be between 0 and 1"
        );
        require(
            _penaltyPercentage <= 100,
            "Penalty percentage must be between 0 and 100"
        );

        platformFeePercentage = _platformFeePercentage;
        penaltyPercentage = _penaltyPercentage;

        emit FeePercentagesUpdated(_platformFeePercentage, _penaltyPercentage);
    }

    /**
     * @dev Withdraws the platform fees to the admin
     * @notice Only an admin can call this function
     */

    function withdrawPlatformFees() public nonReentrant onlyAdmin {
        uint256 balance = address(this).balance;
        payable(admin).transfer(balance);
    }

    /**
     * @dev Calculates the platform fee for a trade
     * @param _tradeId The ID of the trade
     * @return The platform fee amount
     */

    function calculatePlatformFee(
        uint256 _tradeId
    ) internal view returns (uint256) {
        return (escrows[_tradeId].amount * platformFeePercentage) / 100;
    }

    function transferEscrow(
        uint256 _sourceTradeId,
        uint256 _destTradeId,
        uint256 _amount
    ) public nonReentrant onlyTradeContract {
        // Check if the source trade escrow is locked and not released or refunded
        require(
            escrows[_sourceTradeId].isLocked,
            "The source trade escrow is not locked"
        );
        require(
            !escrows[_sourceTradeId].isReleased,
            "The source trade escrow is already released"
        );
        require(
            !escrows[_sourceTradeId].isRefunded,
            "The source trade escrow is already refunded"
        );

        // Check if the destination trade exists
        require(
            _destTradeId > 0 &&
                _destTradeId <= Trade(registry.tradeAddress()).tradeCount(),
            "Destination trade does not exist"
        );

        // Check if the source escrow has sufficient balance
        require(
            escrows[_sourceTradeId].amount >= _amount,
            "Insufficient balance in the source escrow"
        );

        // Transfer the specified amount from the source escrow to the destination escrow
        escrows[_sourceTradeId].amount -= _amount;
        escrows[_destTradeId].amount += _amount;

        // Update the escrow balances and state variables accordingly
        if (escrows[_sourceTradeId].amount == 0) {
            escrows[_sourceTradeId].isLocked = false;
        }
        escrows[_destTradeId].isLocked = true;

        // Emit events for escrow transfer
        emit EscrowTransferred(_sourceTradeId, _destTradeId, _amount);
    }
}
