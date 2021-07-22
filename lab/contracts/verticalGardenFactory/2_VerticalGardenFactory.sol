// SPDX-License-Identifier: MIT
/* LastEdit: 21Jul2021 11:38
**
** PlantSwap.finance - VerticalGarden Factory
** Version:         Beta 2
** Compatibility:   MasterChef(token&LP's) and SmartChef
**
To work on:
    - Build Factory compliant:
        - Add constructor argument
        - Create Contract to own and manage This Factory + MasterGardener
        - Build function to migrate old Vertical Garden?
*/
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./1_VerticalGarden.sol";

contract VerticalGardenFactory is AccessControl {
    
    bool public freezeContract;                                     // Security Freeze this contract if true
    uint16 depositFee = 100; // 1%                                  // Deposit Fee 1/10000 || 1 = 0.01%, 100 = 1%, min: 0, max: 2000 = 20%
    uint16 rewardCut = 1500; // 15%                                 // Reward Cut 1/10000 || 1 = 0.01%, 100 = 1%, min: 0, max: 2500 = 25%
    uint16 rewardCutSplitDevelopmentFund = 50; // 50%               // Reward Cut Split Development Fund 1/100 || 1 = 1%, 100 = 100%, min: 0, max: 100 = 100% (If both value are 0, this will get 100%)
    uint16 rewardCutSplitBuyPlantAndBurn = 50; // 50%               // Reward Cut Split Buy Plant And Burn 1/100 || 1 = 1%, 100 = 100%, min: 0, max: 100 = 100%
    address public developmentFundAdddress = 0xcab64A8d400FD7d9F563292E6135285FD9E54980;    // Development Fund Address.
    address public buyPlantAndBurnAdddress = 0xE5EA440fF25472B09BA31371BF154ed05f1d0182;    // Buy Plant And Burn Address.
    address public depositFeeAddress = 0xcab64A8d400FD7d9F563292E6135285FD9E54980;          // Deposit Fee address
    address public devAddress;                                                              // Dev address for maintenance

    BEP20 constant public plant = BEP20(0x58BA5Bd8872ec18BD360a9592149daed2fC57c69);        // PLANT Token
    MasterGardener public plantMasterGardener = MasterGardener(0x350c56f201f5BcB23F019748123a02e53F8039C4); // Plantswap MasterGardener
    
    bytes32 public constant BUILDER_ROLE = keccak256("BUILDER_ROLE");

    struct VerticalGardenList {
        uint256 blockCreated;
        address stakedToken;
        address rewardToken;
        VerticalGarden verticalGarden;
    }
    mapping(address => VerticalGardenList) public verticalGardenList;
    
    event VerticalGardenCreated(address indexed stakedToken, address indexed rewardToken);

    constructor() {
        depositActive = false;
        devAddress = msg.sender;
    }

    
    function aCreateVerticalGarden(address _stakedToken, address _rewardToken) public view returns (uint256) {
        if(VerticalGardenList.stakedToken !== _stakedToken && VerticalGardenList.rewardToken !== _rewardToken) {
            VerticalGarden verticalGarden = VerticalGarden(_stakedToken, _rewardToken);
                verticalGardens.blockCreated = block.number;
                VerticalGardenList.stackedToken = _stakedToken;
                VerticalGardenList.rewardToken = _rewardToken;
                VerticalGardenList.verticalGarden = verticalGarden;
            VerticalGardenList memory verticalGardenList = verticalGardens[verticalGarden.address];
            VerticalGardenList verticalGardenList = VerticalGardenList(block.number, verticalGarden);
        }
    }
    
    function updateGarden(uint256 _vgId) external nonReentrant gardenActive {
        if(VerticalGardenList._vgId) {
            
        }
    }
    function pendingRewardToken(uint256 _vgId, address _farmer) public view returns (uint256) {}
    function pendingPlantReward(uint256 _vgId, address _farmer) public view returns (uint256) {}
    function estimateRewardToken(uint256 _vgId, address _farmer) public view returns (uint256) {}
    function estimatePlantReward(uint256 _vgId, address _farmer) public view returns (uint256) {}
    function totalWeight(uint256 _vgId) public view returns (uint256) {}
    function gardenerWeight(uint256 _vgId, address _farmer) public view returns (uint256) {}
    function compoundGarden(uint256 _vgId) external nonReentrant gardenActive {}
    function harvestGarden(uint256 _vgId) external nonReentrant gardenActive {}
    function deposit(uint256 _vgId, uint256 amount) external nonReentrant gardenActive {}
    function withdraw(uint256 _vgId, uint256 amount) external nonReentrant gardenActive {}
    function emergencyWithdraw(uint256 _vgId, uint256 amount) public nonReentrant gardenActive {}
    function pendingStakedTokenInStakedTokenMasterChef(uint256 _vgId) public view returns (uint256) {}
    function pendingPlantInPlantMasterGardener(uint256 _vgId) public view returns (uint256) {}
    function userInfoInStakedTokenMasterChef(uint256 _vgId) public view returns (uint256, uint256) {}
    function userInfoInPlantMasterGardener(uint256 _vgId) public view returns (uint256, uint256) {}
    function setStakedTokenApproveMasterChef(uint256 _vgId, address _stakingContract) external {}
    function setStakedTokenMasterChef(uint256 _vgId, 
        address _rewardToken, 
        address _stakingContract, 
        uint16 _pid, 
        bool _rewardTokenDifferentFromStakedToken, 
        bool _stakedTokenMasterChefContractIsSmartChef) external {}
    function setMasterGardening(uint256 _vgId, 
        bool _depositActive, 
        address _stakingContract, 
        uint16 _pid) external {}
    function setVerticalGarden(uint256 _vgId, 
        bool _depositActive,
        uint16 _depositFee, 
        uint16 _rewardCut, 
        uint16 _rewardCutSplitDevelopmentFund, 
        uint16 _rewardCutSplitBuyPlantAndBurn, 
        address _developmentFundAdddress, 
        address _buyPlantAndBurnAdddress, 
        address _depositFeeAddress) external {}
    function setDevAddress(uint256 _vgId, address _devAddress) public {}
    function securityFreezeContract(uint256 _vgId, bool _freeze, uint256 _hoursFreeze) external {}
    function securityControlWithdrawLostToken(uint256 _vgId, uint256 _amount, BEP20 _tokenAddress) external {}
    function securityControlMasterChef(uint256 _vgId, uint256 _amount, bytes32 _action) external {}
    function securityControlMasterGardener(uint256 _vgId, uint256 _amount, bytes32 _action) external {

    }
    
    fallback() external payable {}
    receive() external payable {}
}

interface VerticalGarden {
    function updateGarden() external;
    function pendingRewardToken(address _farmer) public view returns (uint256);
    function pendingPlantReward(address _farmer) public view returns (uint256);
    function estimateRewardToken(address _farmer) public view returns (uint256);
    function estimatePlantReward(address _farmer) public view returns (uint256);
    function totalWeight() public view returns (uint256);
    function gardenerWeight(address _farmer) public view returns (uint256);
    function compoundGarden() external;
    function harvestGarden() external;
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function emergencyWithdraw(uint256 amount) public;
    function pendingStakedTokenInStakedTokenMasterChef() public view returns (uint256);
    function pendingPlantInPlantMasterGardener() public view returns (uint256);
    function userInfoInStakedTokenMasterChef() public view returns (uint256, uint256);
    function userInfoInPlantMasterGardener() public view returns (uint256, uint256);
    function setStakedTokenApproveMasterChef(address _stakingContract) external;
    function setStakedTokenMasterChef(
        address _rewardToken, 
        address _stakingContract, 
        uint16 _pid, 
        bool _rewardTokenDifferentFromStakedToken, 
        bool _stakedTokenMasterChefContractIsSmartChef) external;
    function setMasterGardening(
        bool _depositActive, 
        address _stakingContract, 
        uint16 _pid) external;
    function setVerticalGarden(
        bool _depositActive,
        uint16 _depositFee, 
        uint16 _rewardCut, 
        uint16 _rewardCutSplitDevelopmentFund, 
        uint16 _rewardCutSplitBuyPlantAndBurn, 
        address _developmentFundAdddress, 
        address _buyPlantAndBurnAdddress, 
        address _depositFeeAddress) external;
    function setDevAddress(address _devAddress) public;
    function securityFreezeContract(bool _freeze, uint256 _hoursFreeze) external;
    function securityControlWithdrawLostToken(uint256 _amount, BEP20 _tokenAddress) external;
    function securityControlMasterChef(uint256 _amount, bytes32 _action) external;
    function securityControlMasterGardener(uint256 _amount, bytes32 _action) external;
}
interface StakedTokenMasterChef {
    function pendingCake(uint256 _pid, address _user) external view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function enterStaking(uint256 _amount) external;
    function leaveStaking(uint256 _amount) external;
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);
}
interface StakedTokenSmartChef {
    function pendingReward(address _user) external view returns (uint256);
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function userInfo(address _user) external view returns (uint256, uint256);
}
interface MasterGardener {
    function pendingPlant(uint256 _pid, address _user) external view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
    function safePlantTransfer(address _to, uint256 _amount) external;
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);
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