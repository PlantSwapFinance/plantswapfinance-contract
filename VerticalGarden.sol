// SPDX-License-Identifier: MIT
/* LastEdit: 29June2021 17:13
**
** PlantSwap.finance - VerticalGarden
** Version:         Beta 1.0
** Compatibility:   MasterChef(token&LP's) and SmartChef
**
** Staked Token:    Cake
** Detail:          Harvest StakedToken&Plant reward as the % of the StakedToken the farmer has vs the total.
**                  Pending reward calculated using the formula bellow:
**    (totalPendingRewardTokenRewardToSplit * ((gardener.balanceStakedToken * (block.timestamp - gardener.dateLastUpdate)) / totalStakedTokenEachBlock))
**               
*/
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract VerticalGarden is ERC20, ReentrancyGuard {
    // Place here the token that will be stack
    BEP20 constant public stakedToken = BEP20(0xb27A31f1b0AF2946B7F582768f03239b1eC07c2c); // Test Address
    // Place here the token that will be receive as reward
    BEP20 public rewardToken = BEP20(0xb27A31f1b0AF2946B7F582768f03239b1eC07c2c); // Test Address
    // The stacking contract of the first layer of this garden (PancakeSwap MasterChef, token Cake)
    StakedTokenMasterChef public stakedTokenMasterChef = StakedTokenMasterChef(0xaE036c65C649172b43ef7156b009c6221B596B8b); // Test Address
    // The stacking contract of the first layer of this garden (PancakeSwap SmartChef, token Cake) (use if stakedTokenMasterChefContractIsSmartChef == true)
    StakedTokenSmartChef public stakedTokenSmartChef = StakedTokenSmartChef(0xaE036c65C649172b43ef7156b009c6221B596B8b); // Test Address
    // The pid of the MasterChef pool for the StakedToken
    uint256 public verticalGardenStakedTokenMasterChefPid = 0;
    // The basic amount use to collect reward
    uint256 public verticalGardenStakedTokenMasterChefbasicCollectAmount = 1000000000000000; // 0.001 stakedToken
    // If true it mean the reward from MasterChef is not the same token than the Staked Token
    bool public rewardTokenDifferentFromStakedToken = false;
    // If true it mean the Staking Contract is a SmartChef and not a MasterChef (no pid)
    bool public stakedTokenMasterChefContractIsSmartChef = false;

    // The reward token of the second layer of the garden (Plantswap, token PLANT)
    BEP20 constant public plant = BEP20(0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B); // Test Address
    // The stacking contract of the second layer of this garden (Plantswap MasterGardener, token gStakedToken)
    MasterGardener public plantMasterGardener = MasterGardener(0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47); // Test Address
    uint256 public verticalGardenMasterGardenerPid = 1; // The pid of the MasterGardener pool for gStakedToken

    struct Gardener {
        uint256 balanceStakedToken;
        uint256 gardenersHarvestedRewardToken;
        uint256 gardenersHarvestedPlant;
        uint256 gardenersDeposits;
        uint256 dateStart;
        uint256 dateLastUpdate;
    }
    mapping(address => Gardener) public gardeners;
    mapping(address => uint256) public plantPayoutsTo;
    uint256 public totalStakedToken;
    uint256 public totalRewardTokenRewardHarvested;
    uint256 public totalPlantRewardHarvested;
    uint256 public totalPendingRewardTokenRewardToSplit;
    uint256 public totalPendingPlantRewardToSplit;
    uint256 public totalRewardTokenRewardDistributed;
    uint256 public totalPlantRewardDistributed;
    uint256 public totalStakedTokenEachBlock;
    uint256 public lastRewardTokenUpdateTime; // Block timestamp of the last update
    bool gStakedTokenFarmingActive; // On/Off MasterGardening Farming
    bool public depositActive; // if true, deposit are active
    bool public freezeContract; // Security Freeze this contract if true
    uint256 public freezeContractTillBlock;

    // Deposit Fee 1/10000 || 1 = 0.01%, 100 = 1%, min: 0, max: 2000 = 20%
    uint16 depositFee = 100; // 1%
    // Reward Cut 1/10000 || 1 = 0.01%, 100 = 1%, min: 0, max: 2500 = 25%
    uint16 rewardCut = 1500; // 15%
    // Reward Cut Split Development Fund 1/100 || 1 = 1%, 100 = 100%, min: 0, max: 100 = 100% (If both value are 0, this will get 100%)
    uint16 rewardCutSplitDevelopmentFund = 50; // 50%
    // Reward Cut Split Buy Plant And Burn 1/100 || 1 = 1%, 100 = 100%, min: 0, max: 100 = 100%
    uint16 rewardCutSplitBuyPlantAndBurn = 50; // 50%
    // Development Fund Address.
    address public developmentFundAdddress;
    // Buy Plant And Burn Address.
    address public buyPlantAndBurnAdddress;
    // Deposit Fee address
    address public depositFeeAddress;
    // Dev address for maintenance
    address public devAddress;

    event Deposit(address indexed gardener, uint256 amount);
    event Withdraw(address indexed gardener, uint256 amount);

    constructor(
        bool _depositActive,
        address _developmentFundAdddress,
        address _buyPlantAndBurnAdddress,
        address _depositFeeAddress
    ) ERC20('gCAKE Plantswap.finance Vertical Garden', 'gCAKE') { // The gStaked Token for MasterGardener
        stakedToken.approve(address(stakedTokenMasterChef), 2 ** 255);
        rewardToken.approve(address(stakedTokenMasterChef), 2 ** 255);
        plant.approve(address(plantMasterGardener), 2 ** 255);
        _approve(address(this), address(plantMasterGardener), 2 ** 255);
        lastRewardTokenUpdateTime = block.timestamp;
        gStakedTokenFarmingActive = false;
        depositActive = _depositActive;
        developmentFundAdddress = _developmentFundAdddress;
        buyPlantAndBurnAdddress = _buyPlantAndBurnAdddress;
        depositFeeAddress = _depositFeeAddress;
        devAddress = msg.sender;
    }

    modifier gardenActive {
        require(gStakedTokenFarmingActive == true, "The Vertical garden is not active");
        require(freezeContract == false, "The Vertical garden is frozen");
        if(!freezeContract && freezeContractTillBlock < block.timestamp) {
            _;
        }
    }

    
    function updateGarden() external nonReentrant gardenActive {
        updateReward();
    }
    function updateReward() internal {
        uint256 localVerticalGardenStakedTokenMasterChefbasicCollectAmount = verticalGardenStakedTokenMasterChefbasicCollectAmount;
        uint256 rewardTokenBalanceAtStart = rewardToken.balanceOf(address(this));
        uint256 plantBalanceAtStart = plant.balanceOf(address(this));
        if(lastRewardTokenUpdateTime < block.timestamp && totalStakedToken > 0) {
            uint256 stakedTokenPendingToHarvest;
            if(stakedTokenMasterChefContractIsSmartChef) {
                stakedTokenPendingToHarvest = stakedTokenSmartChef.pendingReward(address(this));
            } else
            {
                stakedTokenPendingToHarvest = stakedTokenMasterChef.pendingCake(verticalGardenStakedTokenMasterChefPid, address(this));
            }
            if(stakedTokenPendingToHarvest > 0 && totalStakedToken > localVerticalGardenStakedTokenMasterChefbasicCollectAmount) { // Harvest if pending & > 0.001 stakedToken in staking
                if(stakedTokenMasterChefContractIsSmartChef) {
                        stakedTokenSmartChef.withdraw(localVerticalGardenStakedTokenMasterChefbasicCollectAmount);
                        stakedTokenSmartChef.deposit(localVerticalGardenStakedTokenMasterChefbasicCollectAmount);
                } else
                {
                    if(verticalGardenStakedTokenMasterChefPid > 0) {
                        stakedTokenMasterChef.withdraw(verticalGardenStakedTokenMasterChefPid, localVerticalGardenStakedTokenMasterChefbasicCollectAmount);
                        stakedTokenMasterChef.deposit(verticalGardenStakedTokenMasterChefPid, localVerticalGardenStakedTokenMasterChefbasicCollectAmount);
                    }
                    else {
                        stakedTokenMasterChef.leaveStaking(localVerticalGardenStakedTokenMasterChefbasicCollectAmount);
                        stakedTokenMasterChef.enterStaking(localVerticalGardenStakedTokenMasterChefbasicCollectAmount);
                    }
                }
                uint256 rewardTokenGained = rewardToken.balanceOf(address(this)) - rewardTokenBalanceAtStart;
                require(rewardTokenGained > 0, "No rewardTokenGained");
                uint256 rewardCutToTake = 0;
                if(rewardCut > 0) {
                    if(rewardCut > 2500) { rewardCut = 2500; } // Limit at 25%
                    rewardCutToTake = ((rewardTokenGained * rewardCut) / (10000));
                    rewardTokenGained -= rewardCutToTake;
                    if(rewardCutSplitBuyPlantAndBurn > 0) {
                        uint256 rewardTokenToBuyPlantAndBurn = ((rewardCutToTake * rewardCutSplitBuyPlantAndBurn) / (rewardCutSplitBuyPlantAndBurn + rewardCutSplitDevelopmentFund));
                        require(rewardToken.transferFrom(address(this), address(buyPlantAndBurnAdddress), rewardTokenToBuyPlantAndBurn), "Error with StakedToken Approval to BuyPlantAndBurn");
                    }
                    if(rewardCutSplitDevelopmentFund > 0) {
                        uint256 rewardTokenToDevelopmentFund = ((rewardCutToTake * rewardCutSplitDevelopmentFund) / (rewardCutSplitBuyPlantAndBurn + rewardCutSplitDevelopmentFund));
                        require(rewardToken.transferFrom(address(this), address(developmentFundAdddress), rewardTokenToDevelopmentFund), "Error with StakedToken Transfer to DevelopmentFund");
                    }
                }
                totalRewardTokenRewardHarvested += rewardTokenGained;
                totalPendingRewardTokenRewardToSplit += rewardTokenGained;
                totalStakedTokenEachBlock += totalStakedToken * (block.timestamp - lastRewardTokenUpdateTime);
                if(!rewardTokenDifferentFromStakedToken) {
                    if(stakedTokenMasterChefContractIsSmartChef) {
                            stakedTokenSmartChef.deposit(rewardTokenGained);
                    } else
                    {
                        if(verticalGardenStakedTokenMasterChefPid > 0) {
                            stakedTokenMasterChef.deposit(verticalGardenStakedTokenMasterChefPid, rewardTokenGained);
                        }
                        else {
                            stakedTokenMasterChef.enterStaking(rewardTokenGained); // Stake StakedToken harvested in PancakeSwap Pool
                        }
                    }
                    _mint(address(this), rewardTokenGained); // Mint gStakedToken harvested
                }
                if(gStakedTokenFarmingActive) { // gCake staking in MasterGardener is setup and active
                    plantMasterGardener.deposit(verticalGardenMasterGardenerPid, rewardTokenGained); // Stake gStakedToken harvested in MasterGardener
                    uint256 plantGained = plant.balanceOf(address(this)) - plantBalanceAtStart;
                    if(plantGained > 0) {
                        totalPlantRewardHarvested += plantGained;
                        totalPendingPlantRewardToSplit += plantGained;
                    }
                }
                lastRewardTokenUpdateTime = block.timestamp;
            }
        }
    }

    function pendingRewardToken(address _farmer) public view returns (uint256) {
        Gardener memory gardener = gardeners[_farmer];
        uint256 expectedRewardToken = 0;
        uint256 blockCount = (block.timestamp - gardener.dateLastUpdate);
        if(totalPendingRewardTokenRewardToSplit > 0 && gardener.balanceStakedToken > 0 && blockCount > 0) {
            expectedRewardToken = totalPendingRewardTokenRewardToSplit * ((gardener.balanceStakedToken * blockCount) / totalStakedTokenEachBlock);
        }
        return expectedRewardToken;
    }

    function pendingPlantReward(address _farmer) public view returns (uint256) {
        Gardener memory gardener = gardeners[_farmer];
        uint256 expectedPlantReward = 0;
        uint256 blockCount = (block.timestamp - gardener.dateLastUpdate);
        if(totalPendingPlantRewardToSplit > 0 && gardener.balanceStakedToken > 0 && blockCount > 0) {
            expectedPlantReward = totalPendingPlantRewardToSplit * ((gardener.balanceStakedToken * blockCount) / totalStakedTokenEachBlock);
        }
        return expectedPlantReward;
    }

    function compoundGarden() external nonReentrant gardenActive {
        updateReward();
        compoundReward();
    }
    function compoundReward() internal {
        address farmer = msg.sender;
        require(!rewardTokenDifferentFromStakedToken, "compoundReward() is only possible if stakedToken == rewardToken");                            
        if(!rewardTokenDifferentFromStakedToken) {
            Gardener memory gardener = gardeners[farmer];
            if(gardener.dateLastUpdate < block.timestamp) {
                if(totalPendingRewardTokenRewardToSplit > 0 && gardener.balanceStakedToken > 0 && gardener.gardenersDeposits > 0) {
                    uint256 blockCount = (block.timestamp - gardener.dateLastUpdate);
                    if(blockCount > 0) {
                        uint256 gardernerWheight = ((gardener.balanceStakedToken * blockCount) / totalStakedTokenEachBlock);
                        uint256 expectedRewardToken = (totalPendingRewardTokenRewardToSplit * gardernerWheight);
                        if(expectedRewardToken > 0 && expectedRewardToken <= totalPendingRewardTokenRewardToSplit) {
                            gardener.balanceStakedToken += expectedRewardToken;
                            gardener.dateLastUpdate = block.timestamp;
                            totalPendingRewardTokenRewardToSplit -= expectedRewardToken;
                            totalRewardTokenRewardDistributed += expectedRewardToken;
                            totalStakedToken += expectedRewardToken;
                            
                            if(totalPendingPlantRewardToSplit > 0) {
                                uint256 expectedPlant = (totalPendingPlantRewardToSplit * gardernerWheight);
                                uint256 gardenerPlantAllowance = plant.allowance(address(farmer), address(this));
                                require(gardenerPlantAllowance >= expectedPlant, "Error with Plant allowance: allowance < expectedPlant");
                                if(expectedPlant > 0 && expectedPlant <= totalPendingPlantRewardToSplit) {
                                    totalPendingPlantRewardToSplit -= expectedPlant;
                                    gardener.gardenersHarvestedPlant += expectedPlant;
                                    totalPlantRewardDistributed += expectedPlant;
                                    uint256 plantBalanceBeforePayout = plant.balanceOf(address(this));
                                    require(plantBalanceBeforePayout >= expectedPlant, "Error with Plant transfer to farmer: Balance < expectedPlant");
                                    require(plant.transferFrom(address(this), farmer, expectedPlant), "Error with Plant transfer to farmer");
                                }
                            }
                            gardeners[farmer] = gardener;
                        }
                    }
                }
            }
        }
    }

    function harvestGarden() external nonReentrant gardenActive {
        updateReward();
        harvestReward();
    }
    function harvestReward() internal {
        address farmer = msg.sender;
        Gardener memory gardener = gardeners[farmer];
        if(gardener.dateLastUpdate < block.timestamp) {
            if(totalPendingRewardTokenRewardToSplit > 0 && gardener.balanceStakedToken > 0 && gardener.gardenersDeposits > 0) {
                uint256 blockCount = (block.timestamp - gardener.dateLastUpdate);
                if(blockCount > 0) {
                    uint256 gardernerWheight = ((gardener.balanceStakedToken * blockCount) / totalStakedTokenEachBlock);
                    uint256 expectedRewardToken = (totalPendingRewardTokenRewardToSplit * gardernerWheight);
                    uint256 gardenerRewardTokenAllowance = rewardToken.allowance(address(farmer), address(this));
                    require(gardenerRewardTokenAllowance >= expectedRewardToken, "Error with StakedToken allowance: allowance < expectedStakedToken");
                    if(expectedRewardToken > 0 && expectedRewardToken <= totalPendingRewardTokenRewardToSplit) {
                        gardener.gardenersHarvestedRewardToken += expectedRewardToken;
                        totalRewardTokenRewardDistributed += expectedRewardToken;
                        totalPendingRewardTokenRewardToSplit -= expectedRewardToken;
                        gardener.dateLastUpdate = block.timestamp;
                        if(stakedTokenMasterChefContractIsSmartChef) {
                            stakedTokenSmartChef.withdraw(expectedRewardToken);
                        } else
                        {
                            if(verticalGardenStakedTokenMasterChefPid > 0) {
                                stakedTokenMasterChef.withdraw(verticalGardenStakedTokenMasterChefPid, expectedRewardToken);
                            }
                            else {
                                stakedTokenMasterChef.leaveStaking(expectedRewardToken);
                            }
                        }
                        if(gStakedTokenFarmingActive) {
                            plantMasterGardener.withdraw(verticalGardenMasterGardenerPid, expectedRewardToken);
                            _burn(address(this), expectedRewardToken);
                        }
                        if(totalPendingPlantRewardToSplit > 0) {
                            uint256 expectedPlant = (totalPendingPlantRewardToSplit * gardernerWheight);
                            uint256 gardenerPlantAllowance = plant.allowance(address(farmer), address(this));
                            require(gardenerPlantAllowance >= expectedPlant, "Error with Plant allowance: allowance < expectedPlant");
                            if(expectedPlant > 0 && expectedPlant <= totalPendingPlantRewardToSplit) {
                                totalPendingPlantRewardToSplit -= expectedPlant;
                                gardener.gardenersHarvestedPlant += expectedPlant;
                                totalPlantRewardDistributed += expectedPlant;
                                uint256 plantBalanceBeforePayout = plant.balanceOf(address(this));
                                require(plantBalanceBeforePayout >= expectedPlant, "Error with Plant transfer to farmer: Balance < expectedPlant");
                                require(plant.transferFrom(address(this), address(farmer), expectedPlant), "Error with Plant transfer to farmer");
                            }
                        }
                        gardeners[farmer] = gardener;
                        require(rewardToken.transferFrom(address(this), address(farmer), expectedRewardToken), "Error with StakedToken transfer to farmer");
                    }
                }
            }
        }
    }

    function deposit(uint256 amount) external nonReentrant gardenActive {
        require(depositActive == true, "Deposit are disable");
        if(totalStakedToken > 0) {
            updateReward();
            if(!rewardTokenDifferentFromStakedToken) {
                compoundReward();
            } else {
               harvestReward();
            }
        }
        address farmer = msg.sender;
        require(farmer == tx.origin);
        uint256 depositAmount = 0;
        if(depositFee > 0) {
            if(depositFee > 2000) { depositFee = 2000; } // Maximum deposit fee 20%
            uint256 depositFeeToTake = (uint256) ((amount * depositFee) / (10000)); // Calculate deposit fee
            depositAmount = (uint256) (amount - depositFeeToTake);
            require(stakedToken.transferFrom(address(farmer), address(depositFeeAddress), depositFeeToTake), "Error with StakedToken transfer from farmer to depositFeesAddress");
            require(stakedToken.transferFrom(address(farmer), address(this), depositAmount), "Error with StakedToken transfer from farmer");
        }
        else {
            depositAmount = amount;
            require(stakedToken.transferFrom(address(farmer), address(this), depositAmount), "Error with StakedToken transfer to farmer");
        }
        if(stakedTokenMasterChefContractIsSmartChef) {
            stakedTokenSmartChef.deposit(depositAmount);
        } else
        {
            if(verticalGardenStakedTokenMasterChefPid > 0) {
                stakedTokenMasterChef.deposit(verticalGardenStakedTokenMasterChefPid, depositAmount);
            }
            else {
                stakedTokenMasterChef.enterStaking(depositAmount); // Stake your StakedToken in PancakeSwap Pool
            }
        }
        _mint(address(this), depositAmount); // Mint gStakedToken
        if(gStakedTokenFarmingActive) { // gCake staking in MasterGardener is setup and active
            plantMasterGardener.deposit(verticalGardenMasterGardenerPid, depositAmount); // Stake gStakedToken in MasterGardener
        }
        Gardener memory gardener = gardeners[farmer];
        gardener.balanceStakedToken += depositAmount;
        gardener.gardenersDeposits += depositAmount;
        if(gardener.dateLastUpdate < 1) {
            gardener.dateStart = block.timestamp;
            gardener.dateLastUpdate = block.timestamp; }
        gardeners[farmer] = gardener;
        totalStakedToken += uint256(depositAmount);
        emit Deposit(msg.sender, depositAmount);
    }

    // Withdraw
    function withdraw(uint256 amount) external nonReentrant gardenActive {
        address farmer = msg.sender;
        uint256 withdrawAmount = amount;
        updateReward();
        harvestReward();
        Gardener memory gardener = gardeners[farmer];
        if(withdrawAmount <= gardener.balanceStakedToken && withdrawAmount <= gardener.gardenersDeposits) {
            gardener.balanceStakedToken -= withdrawAmount;
            gardener.gardenersDeposits -= withdrawAmount;
            gardeners[farmer] = gardener;
            plantPayoutsTo[farmer] += withdrawAmount;
            totalStakedToken -= withdrawAmount;
            if(gardener.balanceStakedToken == 0) {
                gardener.dateStart = 0;
            }
            uint256 gardenerRewardTokenAllowance = stakedToken.allowance(address(farmer), address(this));
            require(gardenerRewardTokenAllowance >= withdrawAmount, "Error with StakedToken allowance: allowance < withdrawAmount");
            if(stakedTokenMasterChefContractIsSmartChef) {
                stakedTokenSmartChef.withdraw(withdrawAmount);
            } else
            {
                if(verticalGardenStakedTokenMasterChefPid > 0) {
                    stakedTokenMasterChef.withdraw(verticalGardenStakedTokenMasterChefPid, withdrawAmount);
                }
                else {
                    stakedTokenMasterChef.leaveStaking(withdrawAmount);
                }
            }
            if(gStakedTokenFarmingActive) { // gCake staking in MasterGardener is setup and active
                plantMasterGardener.withdraw(verticalGardenMasterGardenerPid, withdrawAmount);
            }
            _burn(address(this), withdrawAmount);
            require(stakedToken.transfer(farmer, withdrawAmount), "Error with StakedToken transfer to farmer");
            emit Withdraw(msg.sender, withdrawAmount);
        }
    }

    // How much pending StakedToken in StakedToken Pool (not including what is stack) (Call PancakeSwap MasterChef Contract)
    function pendingStakedTokenInStakedTokenMasterChef() external view returns (uint256) {
        if(stakedTokenMasterChefContractIsSmartChef) {
            return stakedTokenSmartChef.pendingReward(address(this));
        } else
        {
            return stakedTokenMasterChef.pendingCake(verticalGardenStakedTokenMasterChefPid, address(this));
        }
    }

    // How much pending Plant in gStakedToken Pool (not including what is stack) (Call Plantswap MasterGardener Contract)
    function pendingPlantInPlantMasterGardener() external view returns (uint256) {
        return plantMasterGardener.pendingPlant(verticalGardenMasterGardenerPid, address(this));
    }
    
    // How much StakedToken is stack and how much is the reward debt (Call PancakeSwap MasterChef Contract)
    function userInfoInStakedTokenMasterChef() external view returns (uint256, uint256) {
        if(stakedTokenMasterChefContractIsSmartChef) {
            return stakedTokenSmartChef.userInfo(address(this));
        } else
        {
            return stakedTokenMasterChef.userInfo(verticalGardenStakedTokenMasterChefPid, address(this));
        }
    }
    
    // How much gStakedToken is stack and how much is the reward debt (Call Plantswap MasterGardener Contract)
    function userInfoInPlantMasterGardener() external view returns (uint256, uint256) {
        return plantMasterGardener.userInfo(verticalGardenMasterGardenerPid, address(this));
    }

    function setStakedTokenMasterChef(
        address _rewardToken, 
        address stakingContract, 
        uint256 _pid, 
        uint256 _basicCollectAmount,
        bool _rewardTokenDifferentFromStakedToken, 
        bool _stakedTokenMasterChefContractIsSmartChef) external {
        require(msg.sender == devAddress, "You need to be a admin to upgradeStakedTokenMasterChef()");
        rewardToken = BEP20(_rewardToken);
        if(_stakedTokenMasterChefContractIsSmartChef) {
            stakedTokenSmartChef = StakedTokenSmartChef(stakingContract);
        } else {
            stakedTokenMasterChef = StakedTokenMasterChef(stakingContract);
        }
        verticalGardenStakedTokenMasterChefPid = _pid;
        verticalGardenStakedTokenMasterChefbasicCollectAmount = _basicCollectAmount;
        rewardTokenDifferentFromStakedToken = _rewardTokenDifferentFromStakedToken;
        stakedTokenMasterChefContractIsSmartChef = _stakedTokenMasterChefContractIsSmartChef;
        require(stakedToken.approve(stakingContract, 2 ** 255), "Error with StakedToken Approval");
        if(_rewardTokenDifferentFromStakedToken) {
            require(rewardToken.approve(stakingContract, 2 ** 255), "Error with RewardToken Approval");
        }
    }
    
    function setMasterGardening(bool _active, bool _depositActive, address _stakingContract, uint256 _pid) external {
        require(msg.sender == devAddress, "You need to be a admin to upgradeMasterGardening()");
        gStakedTokenFarmingActive = _active;
        depositActive = _depositActive;
        plantMasterGardener = MasterGardener(_stakingContract);
        verticalGardenMasterGardenerPid = _pid;
        _approve(address(this), _stakingContract, 2 ** 255);
        require(plant.approve(_stakingContract, 2 ** 255), "Error with Plant&MasterGardener Approval");

        require(stakedToken.approve(address(this), 2 ** 255), "Error with StakedToken Approval");
        if(rewardTokenDifferentFromStakedToken) {
            require(rewardToken.approve(address(this), 2 ** 255), "Error with RewardToken Approval");
        }
        require(plant.approve(address(this), 2 ** 255), "Error with Plant Approval");
    }

    // Setup depositFee, rewardCut and it's split and change address (improvement -> buy/burn done by smart contract)
    function setVerticalGarden(
        bool _depositActive,
        uint16 _depositFee, 
        uint16 _rewardCut, 
        uint16 _rewardCutSplitDevelopmentFund, 
        uint16 _rewardCutSplitBuyPlantAndBurn, 
        address _developmentFundAdddress, 
        address _buyPlantAndBurnAdddress, 
        address _depositFeeAddress) external {
        require(msg.sender == devAddress, "You need to be a dev to setVerticalGarden()");
        depositActive = _depositActive;
        depositFee = _depositFee;
        rewardCut = _rewardCut;
        rewardCutSplitDevelopmentFund = _rewardCutSplitDevelopmentFund;
        rewardCutSplitBuyPlantAndBurn = _rewardCutSplitBuyPlantAndBurn;
        developmentFundAdddress = _developmentFundAdddress;
        buyPlantAndBurnAdddress = _buyPlantAndBurnAdddress;
        depositFeeAddress = _depositFeeAddress;
    }

    // Setup the Dev. address
    function setDevAddress(address _devAddress) public {
        require(msg.sender == devAddress, "You need to be a dev to setDevAddress()");
        devAddress = _devAddress;
    }

    // Freeze this contract for X hours
    function securityFreezeContract(bool _freeze, uint256 _hoursFreeze) external {
        require(msg.sender == devAddress, "You need to be a dev to securityFreezeContract()");
        if(_freeze == true && _hoursFreeze > 0) {
            freezeContract = true;
            if((block.timestamp + 1 days) > freezeContractTillBlock) {
                uint256 timeToFreeeze = (_hoursFreeze * 1 hours);
                freezeContractTillBlock = (block.timestamp + timeToFreeeze);
            }
        }
    }

    // For beta this function avoids blackholing tokens
    function securityControlWithdrawLostToken(uint256 _amount, BEP20 _tokenAddress) external {
        require(msg.sender == devAddress, "You need to be a admin to securityControlWithdrawLostToken()");
        if(_amount > 0) {
            require(_tokenAddress.transfer(msg.sender, _amount), "Error with Token Transfer");
        }
    }

    // For beta this function avoids blackholing stacked tokens on MasterChef and allow ovewrite deposit/withdraw
    function securityControlMasterChef(uint256 _amount, bytes32 _action) external {
        require(msg.sender == devAddress, "You need to be a admin to securityControlMasterChef()");
        if(_action == "deposit") {
            if(_amount > 0) {
                if(stakedTokenMasterChefContractIsSmartChef) {
                    stakedTokenSmartChef.deposit(_amount);
                } else
                {
                    if(verticalGardenStakedTokenMasterChefPid > 0) {
                        stakedTokenMasterChef.deposit(verticalGardenStakedTokenMasterChefPid, _amount);
                    }
                    else {
                        stakedTokenMasterChef.enterStaking(_amount);
                    }
                }
            }
            require(stakedToken.transferFrom(msg.sender, address(this), _amount), "Error with StakedToken Transfer");
        }
        if(_action == "withdraw") {
            if(_amount > 0) {
                if(stakedTokenMasterChefContractIsSmartChef) {
                    stakedTokenSmartChef.withdraw(_amount);
                } else
                {
                    if(verticalGardenStakedTokenMasterChefPid > 0) {
                        stakedTokenMasterChef.withdraw(verticalGardenStakedTokenMasterChefPid, _amount);
                    }
                    else {
                        stakedTokenMasterChef.leaveStaking(_amount);
                    }
                }
            }
            require(stakedToken.transfer(msg.sender, _amount), "Error with StakedToken Transfer");
        }
    }

    // This function avoids blackholing stacked tokens on MasterGardening and allow ovewrite deposit/withdraw
    function securityControlMasterGardener(uint256 _amount, bytes32 _action) external {
        require(msg.sender == devAddress, "You need to be a admin to securityControlMasterGardener()");
        if(_action == "deposit") {
            if(_amount > 0) {
                plantMasterGardener.deposit(verticalGardenMasterGardenerPid, _amount);
            }
            require(plant.transferFrom(msg.sender, address(this), _amount), "Error with Plant Transfer");
        }
        if(_action == "withdraw") {
            if(_amount > 0) {
                plantMasterGardener.withdraw(verticalGardenMasterGardenerPid, _amount);
            }
            require(plant.transfer(msg.sender, _amount), "Error with Plant Transfer");
        }
    }
    
    fallback() external payable {}
    receive() external payable {}
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