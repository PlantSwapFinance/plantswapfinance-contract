// SPDX-License-Identifier: MIT
/* LastEdit: 22Jul2021 08:15
**
** PlantSwap.finance - Gardeners
** Version:         1.0.0
**
** Detail: This contract is minting Gardeners (NFT's)
**          It's plan for the owner of this contract to be PlantswapGardeningBoard a
**          nd for the different Gardening School and Unisersity to mint NFT's from this contract.
*/
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PlantswapGardeners is ERC721, Ownable {
    using Counters for Counters.Counter;

    mapping(uint8 => uint256) public gardenerCount;                // Map the number of tokens per gardenerId
    mapping(uint8 => uint256) public gardenerBurnCount;            // Map the number of tokens burnt per gardenerId
    Counters.Counter private _tokenIds;                            // Used for generating the tokenId of new NFT minted
    mapping(uint256 => uint8) private gardenerIds;                 // Map the gardenerId for each tokenId
    mapping(uint8 => string) private gardenerNames;                // Map the gardenerName for a tokenId

    // _tokenURIs
    using Strings for uint256;
    mapping (uint256 => string) private _tokenURIs;                 // Optional mapping for token URIs
    string private _baseURIextended;                                // Base URI
    //
    
    constructor() ERC721("Plantswap.finance Gardeners", "PSG") {
    }

    // _tokenURIs
    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }
    
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
    //
    
    function getGardenerId(uint256 _tokenId) external view returns (uint8) {
        return gardenerIds[_tokenId];
    }

    function getGardenerName(uint8 _gardenerId) external view returns (string memory) {
        return gardenerNames[_gardenerId];
    }

    function getGardenerNameOfTokenId(uint256 _tokenId) external view returns (string memory) {
        uint8 gardenerId = gardenerIds[_tokenId];
        return gardenerNames[gardenerId];
    }

    function mint(address _to, string calldata _tokenURI, uint8 _gardenerId) external onlyOwner returns (uint256) {
        uint256 newId = _tokenIds.current();
        _tokenIds.increment();
        gardenerIds[newId] = _gardenerId;
        gardenerCount[_gardenerId] += (uint256) (1);
        _mint(_to, newId);
        _setTokenURI(newId, _tokenURI);
        return newId;
    }

    function setGardenerName(uint8 _gardenerId, string calldata _name) external onlyOwner {
        gardenerNames[_gardenerId] = _name;
    }

    function burn(uint256 _tokenId) external onlyOwner {
        uint8 gardenerIdBurnt = gardenerIds[_tokenId];
        gardenerCount[gardenerIdBurnt] -= (uint256) (1);
        gardenerBurnCount[gardenerIdBurnt] += (uint256) (1);
        _burn(_tokenId);
    }
}