// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ContractRegistry.sol";

/**
 * @title Account contract for managing user profiles and stats
 * @dev This contract handles user registration, profile updates, and maintains user statistics.
 */

contract Account {
    address public owner;

    ContractRegistry public registry;

    struct UserBasicInfo {
        uint256 userId;
        bytes32 userEmail;
        bytes32 userChatHandle;
        bytes32 userWebsite;
        string userAvatar;
        string userRole;
    }

    struct UserStats {
        uint256 userReputationScore;
        uint256 userEndorsementsGiven;
        uint256 userEndorsementsReceived;
        uint256 userRatingsGiven;
        uint256 userRatingsReceived;
        uint256 userDisputesInitiated;
        uint256 userDisputesLost;
        uint256 userTotalTradesInitiated;
        uint256 userTotalTradesAccepted;
        uint256 userTotalTradesCompleted;
        uint256 userTotalTradeVolume;
        uint256 userAverageTradeVolume;
        uint256 userLastCompletedTradeDate;
    }

    mapping(address => UserBasicInfo) public userBasicInfo;
    mapping(address => UserStats) public userStats;
    mapping(uint256 => address) public userIdToAddress;
    uint256 public userCount;

    event UserRegistered(address indexed user, uint256 indexed userId);
    event UserProfileUpdated(address indexed user, uint256 indexed userId);
    event EndorsementGiven(address indexed endorser, address indexed endorsed);
    event EndorsementReceived(
        address indexed endorser,
        address indexed endorsed
    );
    event ReputationUpdated(address indexed user, uint256 newReputationScore);
    event DisputeInitiated(address indexed user);
    event DisputeLost(address indexed user);
    event TradeStatsUpdated(address indexed user);
    event UserRoleUpdated(
        address indexed user,
        uint256 indexed userId,
        string newRole
    );

    constructor(address _registryAddress) {
        owner = msg.sender;
        registry = ContractRegistry(_registryAddress);
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can perform this action"
        );
        _;
    }

    modifier onlyAuthorized() {
        require(
            msg.sender == owner ||
                msg.sender == registry.tradeAddress() ||
                msg.sender == registry.arbitrationAddress(),
            "Only authorized contracts can perform this action"
        );
        _;
    }

    /**
     * @dev Registers a new user with basic information
     * @param _userEmail The user's email address
     * @param _userChatHandle The user's chat handle
     * @param _userWebsite The user's website
     * @param _userAvatar The user's avatar URL
     */

    function userReg(
        bytes32 _userEmail,
        bytes32 _userChatHandle,
        bytes32 _userWebsite,
        string memory _userAvatar
    ) public {
        require(
            userBasicInfo[msg.sender].userId == 0,
            "User already registered"
        );
        require(
            _userEmail != bytes32(0) && _userChatHandle != bytes32(0),
            "Email and chat handle cannot be empty"
        );

        userCount++;
        userBasicInfo[msg.sender] = UserBasicInfo(
            userCount,
            _userEmail,
            _userChatHandle,
            _userWebsite,
            _userAvatar,
            "user"
        );
        userIdToAddress[userCount] = msg.sender;

        emit UserRegistered(msg.sender, userCount);
    }

    /**
     * @dev Updates a user's profile information
     * @param _userEmail The updated user's email address
     * @param _userChatHandle The updated user's chat handle
     * @param _userWebsite The updated user's website
     * @param _userAvatar The updated user's avatar URL
     * @param _userRole The updated user's role (only admin can update)
     */

    function userUpdateProfile(
        bytes32 _userEmail,
        bytes32 _userChatHandle,
        bytes32 _userWebsite,
        string memory _userAvatar,
        string memory _userRole
    ) public {
        require(userBasicInfo[msg.sender].userId != 0, "User not registered");
        require(
            msg.sender == owner ||
                msg.sender == userIdToAddress[userBasicInfo[msg.sender].userId],
            "Only the user or admin can update the profile"
        );

        UserBasicInfo storage user = userBasicInfo[msg.sender];
        user.userEmail = _userEmail;
        user.userChatHandle = _userChatHandle;
        user.userWebsite = _userWebsite;
        user.userAvatar = _userAvatar;

        if (msg.sender == owner) {
            user.userRole = _userRole;
            emit UserRoleUpdated(msg.sender, user.userId, _userRole);
        }

        emit UserProfileUpdated(msg.sender, user.userId);
    }

    /**
     * @dev Calculates and updates a user's reputation score based on various factors
     * @param _user The address of the user
     */

    // This function should be called whenever a user's reputation needs to be updated
    // based on trade volume, active offers, number of trades, trade completion rate,
    // trade partner ratings, endorsements, and a decay function for older trades.
    function userReputationCalc(address _user) public returns (uint256) {
        UserStats storage stats = userStats[_user];

        // Calculate reputation score based on user stats
        uint256 reputationScore = 0;

        // Increase reputation based on completed trades
        reputationScore += stats.userTotalTradesCompleted * 10;

        // Increase reputation based on trade volume
        reputationScore += stats.userTotalTradeVolume / 1 ether;

        // Decrease reputation based on disputes lost
        reputationScore -= stats.userDisputesLost * 50;

        // Increase reputation based on endorsements received
        reputationScore += stats.userEndorsementsReceived * 5;

        // Update user's reputation score
        stats.userReputationScore = reputationScore;

        emit ReputationUpdated(_user, reputationScore);

        return reputationScore;
    }

    /**
     * @dev Updates the number of endorsements given by a user
     * @param _endorser The address of the endorser
     * @param _endorsed The address of the endorsed user
     */

    function updateEndorsementsGiven(
        address _endorser,
        address _endorsed
    ) public onlyAuthorized {
        userStats[_endorser].userEndorsementsGiven++;
        emit EndorsementGiven(_endorser, _endorsed);
    }

    /**
     * @dev Updates the number of endorsements received by a user
     * @param _endorser The address of the endorser
     * @param _endorsed The address of the endorsed user
     */

    function updateEndorsementsReceived(
        address _endorser,
        address _endorsed
    ) public onlyAuthorized {
        userStats[_endorsed].userEndorsementsReceived++;
        emit EndorsementReceived(_endorser, _endorsed);
    }

    /**
     * @dev Updates the number of disputes initiated by a user
     * @param _user The address of the user
     */

    function updateDisputesInitiated(address _user) public onlyAuthorized {
        userStats[_user].userDisputesInitiated++;
        emit DisputeInitiated(_user);
    }

    /**
     * @dev Updates the number of disputes lost by a user
     * @param _user The address of the user
     */

    function updateDisputesLost(address _user) public onlyAuthorized {
        userStats[_user].userDisputesLost++;
        emit DisputeLost(_user);
    }

    /**
     * @dev Updates a user's trade statistics
     * @param _user The address of the user
     * @param _tradeVolume The volume of the trade
     * @param _initiated Whether the trade was initiated by the user
     * @param _accepted Whether the trade was accepted by the user
     * @param _completed Whether the trade was completed
     */

    function updateTradeStats(
        address _user,
        uint256 _tradeVolume,
        bool _initiated,
        bool _accepted,
        bool _completed
    ) public onlyAuthorized {
        require(_tradeVolume > 0, "Trade volume must be greater than 0");

        UserStats storage stats = userStats[_user];
        if (_initiated) {
            stats.userTotalTradesInitiated++;
        }
        if (_accepted) {
            stats.userTotalTradesAccepted++;
        }
        if (_completed) {
            stats.userTotalTradesCompleted++;
            stats.userTotalTradeVolume += _tradeVolume;
            stats.userAverageTradeVolume =
                stats.userTotalTradeVolume /
                stats.userTotalTradesCompleted;
            stats.userLastCompletedTradeDate = block.timestamp;
        }
        emit TradeStatsUpdated(_user);
    }

    /**
     * @dev Retrieves a user's reputation score
     * @param _user The address of the user
     * @return The user's reputation score
     */

    function getUserReputationScore(
        address _user
    ) public view returns (uint256) {
        return userStats[_user].userReputationScore;
    }

    /**
     * @dev Retrieves a user's basic information and statistics
     * @param _user The address of the user
     * @return basicInfo The user's basic information
     * @return stats The user's statistics
     */

    function getUserInfo(
        address _user
    )
        public
        view
        returns (UserBasicInfo memory basicInfo, UserStats memory stats)
    {
        basicInfo = userBasicInfo[_user];
        stats = userStats[_user];
    }
}
