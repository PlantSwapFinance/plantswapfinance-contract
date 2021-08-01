// SPDX-License-Identifier: MIT
/* LastEdit: 01August2021 11:30
**
** PlantSwap.finance - Gardening School
** Version:         1.1.0
**
** Detail: This school is responsible for Gardeners id 1 to 5
*/
pragma solidity 0.8.0;

import "./PlantswapGardeningBoard.sol";

contract GardeningSchool is Ownable {
    PlantswapGardeningBoard public plantswapGardeningBoard;
    BEP20 public plantToken;

    uint256 public blockNumberStart;
    uint256 public blockNumberEnd;
    uint256 public cost;                                    // Cost in PLANT for the NFT
    mapping(address => bool) public hasClaimed;             // Map if address has already claimed a NFT

    string private ipfsHash;                                // IPFS hash for new json
    mapping(uint8 => string) private gardenersIdURIs;         // Map the token number to URI
    uint8 private constant numberGardenersIds = 6;           // number of total series from 1 to 5

    event MintGardener(address indexed to,  uint256 indexed tokenId, uint8 indexed gardenersId);

    constructor(
        PlantswapGardeningBoard _plantswapGardeningBoard,
        BEP20 _plantToken,
        uint256 _cost,
        string memory _ipfsHash,
        uint256 _blockNumberStart,
        uint256 _blockNumberEnd
    ) {
        plantswapGardeningBoard = _plantswapGardeningBoard;
        plantToken = _plantToken;
        cost = _cost;
        ipfsHash = _ipfsHash;
        blockNumberStart = _blockNumberStart;
        blockNumberEnd = _blockNumberEnd;
    }

    function mintGardener(uint8 _gardenersId) external {
        require(!hasClaimed[_msgSender()], "Has claimed");
        require(block.number > blockNumberStart, "too early");
        require(block.number < blockNumberEnd, "too late");
        require(_gardenersId > 0, "gardenersId too low");
        require(_gardenersId < numberGardenersIds, "gardenersId too high");

        hasClaimed[_msgSender()] = true;
        plantToken.transferFrom(address(_msgSender()), address(this), cost);

        string memory tokenURI = gardenersIdURIs[_gardenersId];
        uint256 tokenId = plantswapGardeningBoard.mintCollectible(address(_msgSender()), tokenURI, _gardenersId);

        emit MintGardener(_msgSender(), tokenId, _gardenersId);
    }

    function changeOwnershipNFTContract(address _newOwner) external onlyOwner {
        plantswapGardeningBoard.changeOwnershipNFTContract(_newOwner);
    }

    function claimFee(uint256 _amount) external onlyOwner {
        plantToken.transfer(_msgSender(), _amount);
    }

    function setGardenersJson(uint8 _gardenersId, string calldata _gardenersJson) external onlyOwner {
        require(_gardenersId > 0, "gardenersId too low");
        require(_gardenersId < numberGardenersIds, "gardenersId too high");
        gardenersIdURIs[_gardenersId] = string(abi.encodePacked(ipfsHash, _gardenersJson));
    }

    function setGardenersNames(uint8 _gardenersId, string calldata _gardenersName) external onlyOwner {
        require(_gardenersId > 0, "gardenersId too low");
        require(_gardenersId < numberGardenersIds, "gardenersId too high");
        plantswapGardeningBoard.setGardenerName(_gardenersId, _gardenersName);
    }

    function setBlockNumberStart(uint256 _newBlockNumberStart) external onlyOwner {
        require(_newBlockNumberStart > block.number, "too short");
        blockNumberStart = _newBlockNumberStart;
    }

    function setBlockNumberEnd(uint256 _newBlockNumberEnd) external onlyOwner {
        require(_newBlockNumberEnd > block.number, "too short");
        require(_newBlockNumberEnd > blockNumberStart, "must be > blockNumberStart");
        blockNumberEnd = _newBlockNumberEnd;
    }

    function setCost(uint256 _newCost) external onlyOwner {
        cost = _newCost;
    }

    function canMint(address userAddress) external view returns (bool) {
        if (hasClaimed[userAddress]) {
            return false;
        } else {
            return true;
        }
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