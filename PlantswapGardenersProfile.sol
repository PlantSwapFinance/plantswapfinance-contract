// SPDX-License-Identifier: MIT
/* LastEdit: 01August2021 10:32
**
** Plantswap.finance - Gardeners Profile
** Version:         1.1.0
**
** Detail: This contract is used to create a profile, add point, add team and account type
*/
pragma solidity 0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;
}

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

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

    function getUserProfile(address _userAddress) external view returns (uint256, uint256, uint256, address, uint256, uint256, bool) {
        require(hasRegistered[_userAddress], "Not registered");
        return (
            users[_userAddress].userId,
            users[_userAddress].numberPoints,
            users[_userAddress].teamId,
            users[_userAddress].nftAddress,
            users[_userAddress].tokenId,
            users[_userAddress].accountTypeId,
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