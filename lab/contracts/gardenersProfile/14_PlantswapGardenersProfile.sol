// SPDX-License-Identifier: MIT
/* LastEdit: 22Jul2021 10:32
**
** Plantswap.finance - Gardeners Profile
** Version:         Beta 0.1
**
** Detail: This contract is used to create a profile, add point, add teamc  and account type
*/
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PlantswapGardenersProfile is AccessControl, ERC721Holder {
    using Counters for Counters.Counter;
    BEP20 public plantToken;

    bytes32 public constant NFT_ROLE = keccak256("NFT_ROLE");
    bytes32 public constant POINT_ROLE = keccak256("POINT_ROLE");
    bytes32 public constant SPECIAL_ROLE = keccak256("SPECIAL_ROLE");
    bytes32 public constant ACCTYPE_ROLE = keccak256("ACCTYPE_ROLE");

    uint256 public numberActiveProfiles;
    uint256 public numberPlantToReactivate;
    uint256 public numberPlantToRegister;
    uint256 public numberPlantToUpdate;
    uint256 public numberTeams;
    uint256 public numberAccountTypes;

    mapping(address => bool) public hasRegistered;
    mapping(uint256 => Team) private teams;
    mapping(address => User) private users;
    mapping(uint256 => AccountType) private accountTypes;
    Counters.Counter private _countTeams;                                                                   // Used for generating the teamId
    Counters.Counter private _countUsers;                                                                   // Used for generating the userId
    Counters.Counter private _countAccountTypes;                                                            // Used for generating the accountTypesId

    event TeamAdd(uint256 teamId, string teamName);                                                         // Event to notify a new team is created
    event TeamPointIncrease(uint256 indexed teamId, uint256 numberPoints, uint256 indexed campaignId);      // Event to notify that team points are increased
    event UserChangeTeam(address indexed userAddress, uint256 oldTeamId, uint256 newTeamId);
    event UserNew(address indexed userAddress, uint256 teamId, address nftAddress, uint256 tokenId);      // Event to notify that a user is registered
    event UserPause(address indexed userAddress, uint256 teamId);                                           // Event to notify a user pausing her profile
    event UserPointIncrease(address indexed userAddress, uint256 numberPoints, uint256 indexed campaignId);      // Event to notify that user points are increased
    event UserPointIncreaseMultiple( address[] userAddresses, uint256 numberPoints, uint256 indexed campaignId);      // Event to notify that a list of users have an increase in points
    event UserReactivate( address indexed userAddress, uint256 teamId, address nftAddress, uint256 tokenId);      // Event to notify that a user is reactivating her profile
    event UserUpdate(address indexed userAddress, address nftAddress, uint256 tokenId);      // Event to notify that a user is pausing her profile
    event AccountTypeAdd(uint256 accountTypeId, string typeName);                                 // Event to notify a new account type is created
    event UserChangeAccountType(address indexed userAddress, uint256 oldAccountTypeId, uint256 newAccountTypeId);      // Event to notify that a user is changing his account type 


    modifier onlyOwner() {                                                          // Modifier for admin roles
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not the main admin");
        _;
    }

    modifier onlyPoint() {                                                          // Modifier for point roles
        require(hasRole(POINT_ROLE, _msgSender()), "Not a point admin");
        _;
    }

    modifier onlySpecial() {                                                        // Modifier for special roles
        require(hasRole(SPECIAL_ROLE, _msgSender()), "Not a special admin");
        _;
    }

    modifier onlyAccType() {                                                        // Modifier for Account Type Editor
        require(hasRole(ACCTYPE_ROLE, _msgSender()), "Not a account type editor");
        _;
    }

    struct Team {
        string teamName;
        string teamDescription;
        uint256 numberUsers;
        uint256 numberPoints;
        bool isJoinable;
    }

    struct User {
        uint256 userId;
        uint256 numberPoints;
        uint256 teamId;
        address nftAddress;
        uint256 tokenId;
        uint256 accountTypeId;
        bool isActive;
    }

    struct AccountType {
        string typeName;
        string typeDescription;
        uint256 numberUsers;
        bool isJoinable;
    }

    constructor(
        BEP20 _plantToken,
        uint256 _numberPlantToReactivate,
        uint256 _numberPlantToRegister,
        uint256 _numberPlantToUpdate
    ) {
        plantToken = _plantToken;
        numberPlantToReactivate = _numberPlantToReactivate;
        numberPlantToRegister = _numberPlantToRegister;
        numberPlantToUpdate = _numberPlantToUpdate;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function createProfile(uint256 _teamId, address _nftAddress, uint256 _tokenId) external {
        require(!hasRegistered[_msgSender()], "Already registered");
        require((_teamId <= numberTeams) && (_teamId > 0), "Invalid teamId");
        require(teams[_teamId].isJoinable, "Team not joinable");
        require(hasRole(NFT_ROLE, _nftAddress), "NFT address invalid");
        
        IERC721 nftToken = IERC721(_nftAddress);                                                // Loads the interface to deposit the NFT contract
        require(_msgSender() == nftToken.ownerOf(_tokenId), "Only NFT owner can register");

        nftToken.safeTransferFrom(_msgSender(), address(this), _tokenId);                       // Transfer NFT to this contract
        plantToken.transferFrom(_msgSender(), address(this), numberPlantToRegister);        // Transfer PLANT tokens to this contract
        _countUsers.increment();                                                                // Increment the _countUsers counter and get userId
        uint256 newUserId = _countUsers.current(); 
        users[_msgSender()] = User({
            userId: newUserId,
            numberPoints: 0,
            teamId: _teamId,
            nftAddress: _nftAddress,
            tokenId: _tokenId,
            accountTypeId: 0,
            isActive: true });                                                              // Add data to the struct for newUserId          
        hasRegistered[_msgSender()] = true;                                                 // Update registration status
        numberActiveProfiles += (uint256) (1);                                 // Update number of active profiles
        teams[_teamId].numberUsers += (uint256) (1);                                         // Increase the number of users for the team
        emit UserNew(_msgSender(), _teamId, _nftAddress, _tokenId);                         // Emit an event
    }

    function pauseProfile() external {
        require(hasRegistered[_msgSender()], "Has not registered");
        require(users[_msgSender()].isActive, "User not active");                           // Checks whether user has already paused
        users[_msgSender()].isActive = false;                                               // Change status of user to make it inactive
        uint256 userTeamId = users[_msgSender()].teamId;                                    // Retrieve the teamId of the user calling
        teams[userTeamId].numberUsers -= (uint256) (1);             // Reduce number of active users and team users
        numberActiveProfiles -= (uint256) (1);  
        IERC721 nftToken = IERC721(users[_msgSender()].nftAddress);                         // Interface to deposit the NFT contract
        uint256 redeemedTokenId = users[_msgSender()].tokenId;                              // tokenId of NFT redeemed
        users[_msgSender()].nftAddress = address(0x0000000000000000000000000000000000000000);      // Change internal statuses as extra safety
        users[_msgSender()].tokenId = 0;
        nftToken.safeTransferFrom(address(this), _msgSender(), redeemedTokenId);            // Transfer the NFT back to the user
        emit UserPause(_msgSender(), userTeamId);                                           // Emit event
    }

    function updateProfile(address _nftAddress, uint256 _tokenId) external {
        require(hasRegistered[_msgSender()], "Has not registered");
        require(hasRole(NFT_ROLE, _nftAddress), "NFT address invalid");
        require(users[_msgSender()].isActive, "User not active");
        address currentAddress = users[_msgSender()].nftAddress;
        uint256 currentTokenId = users[_msgSender()].tokenId;
        IERC721 nftNewToken = IERC721(_nftAddress);                                         // Interface to deposit the NFT contract
        require(_msgSender() == nftNewToken.ownerOf(_tokenId), "Only NFT owner can update");
        nftNewToken.safeTransferFrom(_msgSender(), address(this), _tokenId);                // Transfer token to new address
        plantToken.transferFrom(_msgSender(), address(this), numberPlantToUpdate);      // Transfer PLANT token to this address
        IERC721 nftCurrentToken = IERC721(currentAddress);                                  // Interface to deposit the NFT contract
        nftCurrentToken.safeTransferFrom(address(this), _msgSender(), currentTokenId);      // Transfer old token back to the owner
        users[_msgSender()].nftAddress = _nftAddress;                                       // Update mapping in storage
        users[_msgSender()].tokenId = _tokenId;
        emit UserUpdate(_msgSender(), _nftAddress, _tokenId);
    }

    function reactivateProfile(address _nftAddress, uint256 _tokenId) external {
        require(hasRegistered[_msgSender()], "Has not registered");
        require(hasRole(NFT_ROLE, _nftAddress), "NFT address invalid");
        require(!users[_msgSender()].isActive, "User is active");

        IERC721 nftToken = IERC721(_nftAddress);        // Interface to deposit the NFT contract
        require(_msgSender() == nftToken.ownerOf(_tokenId), "Only NFT owner can update");
        plantToken.transferFrom(_msgSender(), address(this), numberPlantToReactivate);  // Transfer to this address
        nftToken.safeTransferFrom(_msgSender(), address(this), _tokenId);       // Transfer NFT to contract
        uint256 userTeamId = users[_msgSender()].teamId;                        // Retrieve teamId of the user
        teams[userTeamId].numberUsers += (uint256) (1);    // Update number of users for the team and number of active profiles
        users[_msgSender()].isActive = true;                                    // Update user statuses
        users[_msgSender()].nftAddress = _nftAddress;
        users[_msgSender()].tokenId = _tokenId;
        emit UserReactivate(_msgSender(), userTeamId, _nftAddress, _tokenId);
    }

    function increaseUserPoints(address _userAddress, uint256 _numberPoints, uint256 _campaignId) external onlyPoint {
        users[_userAddress].numberPoints += (uint256) (_numberPoints);     // Increase the number of points for the user
        emit UserPointIncrease(_userAddress, _numberPoints, _campaignId);
    }

    function increaseUserPointsMultiple(address[] calldata _userAddresses, uint256 _numberPoints, uint256 _campaignId) external onlyPoint {
        require(_userAddresses.length < 1001, "Length must be < 1001");
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            users[_userAddresses[i]].numberPoints += (uint256) (_numberPoints);
        }
        emit UserPointIncreaseMultiple(_userAddresses, _numberPoints, _campaignId);
    }

    function increaseTeamPoints(uint256 _teamId, uint256 _numberPoints, uint256 _campaignId) external onlyPoint {
        teams[_teamId].numberPoints += (uint256) (_numberPoints);      // Increase the number of points for the team
        emit TeamPointIncrease(_teamId, _numberPoints, _campaignId);
    }

    function removeUserPoints(address _userAddress, uint256 _numberPoints) external onlyPoint {
        users[_userAddress].numberPoints -= (uint256) (_numberPoints); // Increase the number of points for the user
    }

    function removeUserPointsMultiple(address[] calldata _userAddresses, uint256 _numberPoints) external onlyPoint {
        require(_userAddresses.length < 1001, "Length must be < 1001");
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            users[_userAddresses[i]].numberPoints -= (uint256) (_numberPoints);
        }
    }

    function removeTeamPoints(uint256 _teamId, uint256 _numberPoints) external onlyPoint {
        teams[_teamId].numberPoints -= (uint256) (_numberPoints);   // Increase the number of points for the team
    }

    function addNftAddress(address _nftAddress) external onlyOwner {
        require(IERC721(_nftAddress).supportsInterface(0x80ac58cd), "Not ERC721");
        grantRole(NFT_ROLE, _nftAddress);
    }

    function addTeam(string calldata _teamName, string calldata _teamDescription) external onlyOwner {
        bytes memory strBytes = bytes(_teamName);                   
        require(strBytes.length < 20, "Must be < 20");           // Verify length is between 3 and 16
        require(strBytes.length > 3, "Must be > 3");
        _countTeams.increment();                                // Increment the _countTeams counter and get teamId
        uint256 newTeamId = _countTeams.current();
        teams[newTeamId] = Team({                               // Add new team data to the struct
            teamName: _teamName,
            teamDescription: _teamDescription,
            numberUsers: 0,
            numberPoints: 0,
            isJoinable: true });
        numberTeams = newTeamId;
        emit TeamAdd(newTeamId, _teamName);
    }

    function changeTeam(address _userAddress, uint256 _newTeamId) external onlySpecial {
        require(hasRegistered[_userAddress], "User doesn't exist");
        require((_newTeamId <= numberTeams) && (_newTeamId > 0), "teamId doesn't exist" );
        require(teams[_newTeamId].isJoinable, "Team not joinable");
        require(users[_userAddress].teamId != _newTeamId, "Already in the team");
        uint256 oldTeamId = users[_userAddress].teamId;                             // Get old teamId
        teams[oldTeamId].numberUsers -= (uint256) (1);         // Change number of users in old team
        users[_userAddress].teamId = _newTeamId;                                    // Change teamId in user mapping
        teams[_newTeamId].numberUsers += (uint256) (1);       // Change number of users in new team

        emit UserChangeTeam(_userAddress, oldTeamId, _newTeamId);
    }

    function addAccountType(string calldata _typeName, string calldata _typeDescription) external onlyOwner {
        bytes memory strBytes = bytes(_typeName);                   
        require(strBytes.length < 20, "Must be < 20");           // Verify length is between 3 and 16
        require(strBytes.length > 3, "Must be > 3");
        _countAccountTypes.increment();                                // Increment the _countAccountTypes counter and get acountTypeId
        uint256 newAccountTypeId = _countAccountTypes.current();
        accountTypes[newAccountTypeId] = AccountType({                               // Add new team data to the struct
            typeName: _typeName,
            typeDescription: _typeDescription,
            numberUsers: 0,
            isJoinable: true });
        numberAccountTypes = newAccountTypeId;
        emit AccountTypeAdd(newAccountTypeId, _typeName);
    }

    function changeAccountType(address _userAddress, uint256 _newAccountTypeId) external onlyAccType {
        require(hasRegistered[_userAddress], "User doesn't exist");
        require((_newAccountTypeId <= numberAccountTypes) && (_newAccountTypeId > 0), "accountTypeId doesn't exist" );
        require(accountTypes[_newAccountTypeId].isJoinable, "AccountType not joinable");
        require(users[_userAddress].accountTypeId != _newAccountTypeId, "Already in the team");
        uint256 oldAccountTypeId = users[_userAddress].accountTypeId;                             // Get old accountTypeId
        accountTypes[oldAccountTypeId].numberUsers -= (uint256) (1);         // Change number of users in old team
        users[_userAddress].accountTypeId = _newAccountTypeId;                                    // Change accountTypeId in user mapping
        accountTypes[_newAccountTypeId].numberUsers += (uint256) (1);       // Change number of users in new team

        emit UserChangeAccountType(_userAddress, oldAccountTypeId, _newAccountTypeId);
    }

    function makeAccountTypeJoinable(uint256 _accountTypeId) external onlyOwner {
        require((_accountTypeId <= numberAccountTypes) && (_accountTypeId > 0), "accountTypeId invalid");
        accountTypes[_accountTypeId].isJoinable = true;
    }

    function makeAccountTypeNotJoinable(uint256 _accountTypeId) external onlyOwner {
        require((_accountTypeId <= numberAccountTypes) && (_accountTypeId > 0), "accountTypeId invalid");
        accountTypes[_accountTypeId].isJoinable = false;
    }

    function renameAccountType(uint256 _accountTypeId, string calldata _typeName, string calldata _typeDescription) external onlyOwner {
        require((_accountTypeId <= numberAccountTypes) && (_accountTypeId > 0), "accountTypeId invalid");
        bytes memory strBytes = bytes(_typeName);
        require(strBytes.length < 20, "Must be < 20");      // Verify length is between 3 and 16
        require(strBytes.length > 3, "Must be > 3");
        accountTypes[_accountTypeId].typeName = _typeName;
        accountTypes[_accountTypeId].typeDescription = _typeDescription;
    }

    function getAccountTypeProfile(uint256 _accountTypeId) external view returns (string memory, string memory, uint256, bool) {
        require((_accountTypeId <= numberAccountTypes) && (_accountTypeId > 0), "accountTypeId invalid");
        return (
            accountTypes[_accountTypeId].typeName,
            accountTypes[_accountTypeId].typeDescription,
            accountTypes[_accountTypeId].numberUsers,
            accountTypes[_accountTypeId].isJoinable
        );
    }

    function claimFee(uint256 _amount) external onlyOwner {
        plantToken.transfer(_msgSender(), _amount);
    }

    function makeTeamJoinable(uint256 _teamId) external onlyOwner {
        require((_teamId <= numberTeams) && (_teamId > 0), "teamId invalid");
        teams[_teamId].isJoinable = true;
    }

    function makeTeamNotJoinable(uint256 _teamId) external onlyOwner {
        require((_teamId <= numberTeams) && (_teamId > 0), "teamId invalid");
        teams[_teamId].isJoinable = false;
    }

    function renameTeam(uint256 _teamId, string calldata _teamName, string calldata _teamDescription) external onlyOwner {
        require((_teamId <= numberTeams) && (_teamId > 0), "teamId invalid");
        bytes memory strBytes = bytes(_teamName);
        require(strBytes.length < 20, "Must be < 20");      // Verify length is between 3 and 16
        require(strBytes.length > 3, "Must be > 3");
        teams[_teamId].teamName = _teamName;
        teams[_teamId].teamDescription = _teamDescription;
    }

    function updateNumberPlant(uint256 _newNumberPlantToReactivate, uint256 _newNumberPlantToRegister, uint256 _newNumberPlantToUpdate) external onlyOwner {
        numberPlantToReactivate = _newNumberPlantToReactivate;
        numberPlantToRegister = _newNumberPlantToRegister;
        numberPlantToUpdate = _newNumberPlantToUpdate;
    }

    function getUserProfile(address _userAddress) external view returns (uint256, uint256, uint256, address, uint256, bool) {
        require(hasRegistered[_userAddress], "Not registered");
        return (
            users[_userAddress].userId,
            users[_userAddress].numberPoints,
            users[_userAddress].teamId,
            users[_userAddress].nftAddress,
            users[_userAddress].tokenId,
            users[_userAddress].isActive
        );
    }

    function getUserStatus(address _userAddress) external view returns (bool) {
        return (users[_userAddress].isActive);
    }

    function getTeamProfile(uint256 _teamId) external view returns (string memory, string memory, uint256, uint256, bool) {
        require((_teamId <= numberTeams) && (_teamId > 0), "teamId invalid");
        return (
            teams[_teamId].teamName,
            teams[_teamId].teamDescription,
            teams[_teamId].numberUsers,
            teams[_teamId].numberPoints,
            teams[_teamId].isJoinable
        );
    }
}

interface BEP20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address who) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function approve(address spender, uint256 value) external returns (bool);
  function approveAndCall(address spender, uint tokens, bytes calldata data) external returns (bool success);
  function transferFrom(address from, address to, uint256 value) external returns (bool);
  function burn(uint256 amount) external;
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}