// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ContractRegistry {
    address public accountAddress;
    address public offerAddress;
    address public tradeAddress;
    address public escrowAddress;
    address public ratingAddress;
    address public reputationAddress;
    address public arbitrationAddress;

    address public owner;

    event ContractAddressUpdated(string contractName, address newAddress);

    constructor(
        address _accountAddress,
        address _offerAddress,
        address _tradeAddress,
        address _escrowAddress,
        address _ratingAddress,
        address _reputationAddress,
        address _arbitrationAddress
    ) {
        owner = msg.sender;
        accountAddress = _accountAddress;
        offerAddress = _offerAddress;
        tradeAddress = _tradeAddress;
        escrowAddress = _escrowAddress;
        ratingAddress = _ratingAddress;
        reputationAddress = _reputationAddress;
        arbitrationAddress = _arbitrationAddress;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can perform this action"
        );
        _;
    }

    function updateAddresses(
        address _accountAddress,
        address _offerAddress,
        address _tradeAddress,
        address _escrowAddress,
        address _ratingAddress,
        address _reputationAddress,
        address _arbitrationAddress
    ) public onlyOwner {
        accountAddress = _accountAddress;
        offerAddress = _offerAddress;
        tradeAddress = _tradeAddress;
        escrowAddress = _escrowAddress;
        ratingAddress = _ratingAddress;
        reputationAddress = _reputationAddress;
        arbitrationAddress = _arbitrationAddress;

        emit ContractAddressUpdated("Account", _accountAddress);
        emit ContractAddressUpdated("Offer", _offerAddress);
        emit ContractAddressUpdated("Trade", _tradeAddress);
        emit ContractAddressUpdated("Escrow", _escrowAddress);
        emit ContractAddressUpdated("Rating", _ratingAddress);
        emit ContractAddressUpdated("Reputation", _reputationAddress);
        emit ContractAddressUpdated("Arbitration", _arbitrationAddress);
    }

    // Just update the Offer contract address
    function updateOfferAddress(address _offerAddress) public onlyOwner {
        require(_offerAddress != address(0), "Invalid Offer address");
        offerAddress = _offerAddress;
    }
}
