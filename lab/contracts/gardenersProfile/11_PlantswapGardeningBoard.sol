// SPDX-License-Identifier: MIT
/* LastEdit: 22Jul2021 08:18
**
** PlantSwap.finance - PlantswapGardeningBoard
** Version:         Beta 0.1
**
** Detail:          This contract own PlantswapFarmers and control the contract that can mint new farmers or edit them.
*/

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./10_PlantswapGardeners.sol";

contract PlantswapGardeningBoard is AccessControl {
    PlantswapGardeners public plantswapGardeners;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "Not a minting role");
        _;
    }

    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not an admin role");
        _;
    }

    constructor(PlantswapGardeners _plantswapGardeners) {
        plantswapGardeners = _plantswapGardeners;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function mintCollectible(address _tokenReceiver, string calldata _tokenURI, uint8 _gardenersId) external onlyMinter returns (uint256) {
        uint256 tokenId = plantswapGardeners.mint(_tokenReceiver, _tokenURI, _gardenersId);
        return tokenId;
    }

    function setGardenerName(uint8 _gardenersId, string calldata _gardenersName) external onlyOwner {
        plantswapGardeners.setGardenerName(_gardenersId, _gardenersName);
    }

    function changeOwnershipNFTContract(address _newOwner) external onlyOwner {
        plantswapGardeners.transferOwnership(_newOwner);
    }
}