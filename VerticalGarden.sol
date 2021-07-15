// SPDX-License-Identifier: MIT
/* LastEdit: 14Jul2021 20:09
**
** PlantSwap.finance - VerticalGarden
** Version:         Beta 0.9
** Compatibility:   MasterChef(token&LP's) and SmartChef
**
** Staked Token:    Cake
** Detail:          Harvest StakedToken&Plant reward as the % of the StakedToken the farmer has vs the total.
**                  Pending reward for each gardener is calculated using the formula bellow:
**                  (uint256(totalPendingRewardTokenRewardToSplit) * (uint256(gardener.balance) * (uint256(block.number) - uint256(gardener.dateLastUpdate)))) / (uint256(totalStakedTokenEachBlock) + ((uint256(block.number) - uint256(lastRewardUpdateBlock)) * uint256(totalStakedToken))));
**                  When a new deposit occur, the deposited token get stack in the masterchef, then this contract mint the same amount of token as gStakedToken
**                  and stake them in the mastergardener contract at the next trigger update of the contract.
**                  Plant reward payout get paid on harvest, compound, deposit and withdraw.
**                  New deposit should trigger automatic compound if you have pending reward
**                  Withdraw should trigger harvest of pending reward
**                  EmergencyWithdraw will forfeit to other farmer your pending reward
*/
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract VerticalGarden is ERC20, ReentrancyGuard {
    
    bool public depositActive; // if true, deposit are active
    bool public freezeContract; // Security Freeze this contract if true
    // If true it mean the reward from MasterChef is not the same token than the Staked Token
    bool public rewardTokenDifferentFromStakedToken = false;
    // If true it mean the Staking Contract is a SmartChef and not a MasterChef (no pid)
    bool public stakedTokenMasterChefContractIsSmartChef = false;
    // The pid of the MasterChef pool for the StakedToken
    uint16 public verticalGardenStakedTokenMasterChefPid = 0;
    uint16 public verticalGardenMasterGardenerPid = 1; // The pid of the MasterGardener pool for gStakedToken

    // Deposit Fee 1/10000 || 1 = 0.01%, 100 = 1%, min: 0, max: 2000 = 20%
    uint16 depositFee = 100; // 1%
    // Reward Cut 1/10000 || 1 = 0.01%, 100 = 1%, min: 0, max: 2500 = 25%
    uint16 rewardCut = 1500; // 15%
    // Reward Cut Split Development Fund 1/100 || 1 = 1%, 100 = 100%, min: 0, max: 100 = 100% (If both value are 0, this will get 100%)
    uint16 rewardCutSplitDevelopmentFund = 50; // 50%
    // Reward Cut Split Buy Plant And Burn 1/100 || 1 = 1%, 100 = 100%, min: 0, max: 100 = 100%
    uint16 rewardCutSplitBuyPlantAndBurn = 50; // 50%
    
    // Development Fund Address.
    address public developmentFundAdddress = 0xcab64A8d400FD7d9F563292E6135285FD9E54980;
    // Buy Plant And Burn Address.
    address public buyPlantAndBurnAdddress = 0xE5EA440fF25472B09BA31371BF154ed05f1d0182;
    // Deposit Fee address
    address public depositFeeAddress = 0xcab64A8d400FD7d9F563292E6135285FD9E54980;
    // Dev address for maintenance
    address public devAddress;

    // Place here the token that will be stack
    BEP20 constant public stakedToken = BEP20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82); // CAKE
    // Place here the token that will be receive as reward
    BEP20 public rewardToken = BEP20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82); // CAKE
    // The stacking contract of the first layer of this garden (PancakeSwap MasterChef, token Cake)
    StakedTokenMasterChef public stakedTokenMasterChef = StakedTokenMasterChef(0x73feaa1eE314F8c655E354234017bE2193C9E24E); // PancakeSwap MasterChef
    // The stacking contract of the first layer of this garden (PancakeSwap SmartChef, token Cake) (use if stakedTokenMasterChefContractIsSmartChef == true)
    StakedTokenSmartChef public stakedTokenSmartChef = StakedTokenSmartChef(0x73feaa1eE314F8c655E354234017bE2193C9E24E); // PancakeSwap MasterChef
    // The reward token of the second layer of the garden (Plantswap, token PLANT)
    BEP20 constant public plant = BEP20(0x58BA5Bd8872ec18BD360a9592149daed2fC57c69);
    // The stacking contract of the second layer of this garden (Plantswap MasterGardener, token gStakedToken)
    MasterGardener public plantMasterGardener = MasterGardener(0x350c56f201f5BcB23F019748123a02e53F8039C4);
    
    struct Gardener {
        uint256 balance;
        uint256 dateLastUpdate;
    }
    mapping(address => Gardener) public gardeners;
    mapping(address => uint256) public harvestedReward;
    mapping(address => uint256) public harvestedPlant;
    uint256 public totalStakedToken;
    uint256 public totalPendingRewardTokenRewardToSplit;
    uint256 public totalPendingPlantRewardToSplit;
    uint256 public totalStakedTokenEachBlock;
    uint256 public toStakeGStakedToken;
    uint256 public lastRewardUpdateBlock; // Block of the last update
    uint256 public lastRewardUpdateBlockPrevious; // Block number at previous update
    uint256 public lastRewardUpdateTotalStakedToken; // totalStakedToken at previous update
    uint256 public lastRewardUpdateRewardTokenGained; // rewardTokenGained at previous update
    uint256 public lastRewardUpdatePlantGained; // plantGained at previous update
    uint256 public freezeContractTillBlock;

    event Deposit(address indexed gardener, uint256 amount);
    event Withdraw(address indexed gardener, uint256 amount);
    event CompoundRewardToken(address indexed gardener, uint256 amount);
    event HarvestPlantReward(address indexed gardener, uint256 amount);
    event HarvestRewardToken(address indexed gardener, uint256 amount);

    constructor(
    ) ERC20('gCAKE Plantswap.finance Vertical Garden', 'gCAKE') {
        depositActive = false;
        devAddress = msg.sender;
    }

    modifier gardenActive {
        require(freezeContract == false, "The Vertical garden is frozen");
        if(!freezeContract && freezeContractTillBlock < block.number) {
            _;
        }
    }
    
    function updateGarden() external nonReentrant gardenActive {
        updateReward();
    }
    function updateReward() internal {
        if(totalStakedToken > 0) {
            uint256 rewardTokenBalanceAtStart = rewardToken.balanceOf(address(this));
            uint256 plantBalanceAtStart = plant.balanceOf(address(this));
            if(lastRewardUpdateBlock < block.number) {
                if(stakedTokenMasterChefContractIsSmartChef) {
                    stakedTokenSmartChef.deposit(0);
                } else
                {
                    if(verticalGardenStakedTokenMasterChefPid > 0) {
                        stakedTokenMasterChef.deposit(verticalGardenStakedTokenMasterChefPid, 0);
                    }
                    else {
                        stakedTokenMasterChef.enterStaking(0);
                    }
                }
                uint256 rewardTokenGained = rewardToken.balanceOf(address(this)) - rewardTokenBalanceAtStart;
                require(rewardTokenGained > 0, "No rewardTokenGained");
                uint256 rewardCutToTake = 0;
                if(rewardCut > 0) {
                    if(rewardCut > 2500) { rewardCut = 2500; } // Limit at 25%
                    rewardCutToTake = ((rewardTokenGained * rewardCut) / (10000));
                    rewardTokenGained -= uint256(rewardCutToTake);
                    if(rewardCutSplitBuyPlantAndBurn > 0) {
                        uint256 rewardTokenToBuyPlantAndBurn = ((rewardCutToTake * rewardCutSplitBuyPlantAndBurn) / (rewardCutSplitBuyPlantAndBurn + rewardCutSplitDevelopmentFund));
                        require(rewardToken.transferFrom(address(this), address(buyPlantAndBurnAdddress), rewardTokenToBuyPlantAndBurn), "Error with StakedToken Approval to BuyPlantAndBurn");
                    }
                    if(rewardCutSplitDevelopmentFund > 0) {
                        uint256 rewardTokenToDevelopmentFund = ((rewardCutToTake * rewardCutSplitDevelopmentFund) / (rewardCutSplitBuyPlantAndBurn + rewardCutSplitDevelopmentFund));
                        require(rewardToken.transferFrom(address(this), address(developmentFundAdddress), rewardTokenToDevelopmentFund), "Error with StakedToken Transfer to DevelopmentFund");
                    }
                }
                totalPendingRewardTokenRewardToSplit += uint256(rewardTokenGained);
                lastRewardUpdateRewardTokenGained = uint256(rewardTokenGained);
                totalStakedTokenEachBlock += uint256(totalStakedToken) * (uint256(block.number) - uint256(lastRewardUpdateBlock));
                lastRewardUpdateTotalStakedToken = uint256(totalStakedToken);
                uint256 gStakedTokenToMintAndStake = 0;
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
                    gStakedTokenToMintAndStake += rewardTokenGained;
                }
                if(toStakeGStakedToken > 0) {
                    gStakedTokenToMintAndStake += toStakeGStakedToken;
                }
                if(gStakedTokenToMintAndStake > 0) {
                    _mint(address(this), gStakedTokenToMintAndStake); // Mint gStakedToken harvested and previously deposited
                    plantMasterGardener.deposit(verticalGardenMasterGardenerPid, gStakedTokenToMintAndStake); // Stake gStakedToken harvested in MasterGardener
                }
                else {
                    plantMasterGardener.deposit(verticalGardenMasterGardenerPid, 0); // Harvest
                }
                uint256 plantGained = plant.balanceOf(address(this)) - plantBalanceAtStart;
                if(plantGained > 0) {
                    totalPendingPlantRewardToSplit += uint256(plantGained);
                    lastRewardUpdatePlantGained = uint256(plantGained);
                }
                lastRewardUpdateBlockPrevious = uint256(lastRewardUpdateBlock);
                lastRewardUpdateBlock = uint256(block.number);
            }
        }
    }

    function pendingRewardToken(address _farmer) public view returns (uint256) {
        uint256 lTotalPendingRewardTokenRewardToSplit = totalPendingRewardTokenRewardToSplit;
        uint256 lTotalWeight = totalWeight();
        uint256 lGardenerWeight = gardenerWeight(_farmer);
        uint256 lExpectedRewardToken = 0;
        if(lTotalPendingRewardTokenRewardToSplit > 0 && lGardenerWeight > 0 && lTotalWeight > 0) {
            lExpectedRewardToken = ((uint256(lTotalPendingRewardTokenRewardToSplit) * uint256(lGardenerWeight)) / uint256(lTotalWeight));
        }
        return lExpectedRewardToken;
    }

    function pendingPlantReward(address _farmer) public view returns (uint256) {
        uint256 lTotalPendingPlantRewardToSplit = totalPendingPlantRewardToSplit;
        uint256 lTotalWeight = totalWeight();
        uint256 lGardenerWeight = gardenerWeight(_farmer);
        uint256 lExpectedPlantReward = 0;
        if(lTotalPendingPlantRewardToSplit > 0 && lGardenerWeight > 0 && lTotalWeight > 0) {
            lExpectedPlantReward = ((uint256(lTotalPendingPlantRewardToSplit) * uint256(lGardenerWeight)) / uint256(lTotalWeight));
        }
        return lExpectedPlantReward;
    }

    function estimateRewardToken(address _farmer) public view returns (uint256) {
        uint256 lTotalPendingRewardTokenRewardToSplit = totalPendingRewardTokenRewardToSplit;
        uint256 lTotalWeight = totalWeight();
        uint256 lGardenerWeight = gardenerWeight(_farmer);
        uint256 lTotalPendingInMasterChef = pendingStakedTokenInStakedTokenMasterChef();
        uint256 lExpectedRewardToken = 0;
        if(lTotalPendingRewardTokenRewardToSplit > 0 && lGardenerWeight > 0 && lTotalWeight > 0) {
            lExpectedRewardToken = (((uint256(lTotalPendingRewardTokenRewardToSplit) + uint256(lTotalPendingInMasterChef)) * uint256(lGardenerWeight)) / uint256(lTotalWeight));
        }
        return lExpectedRewardToken;
    }

    function estimatePlantReward(address _farmer) public view returns (uint256) {
        uint256 lTotalPendingPlantRewardToSplit = totalPendingPlantRewardToSplit;
        uint256 lTotalWeight = totalWeight();
        uint256 lGardenerWeight = gardenerWeight(_farmer);
        uint256 lTotalPendingInMasterGardener = pendingPlantInPlantMasterGardener();
        uint256 lExpectedPlantReward = 0;
        if(lTotalPendingPlantRewardToSplit > 0 && lGardenerWeight > 0 && lTotalWeight > 0) {
            lExpectedPlantReward = (((uint256(lTotalPendingPlantRewardToSplit) + uint256(lTotalPendingInMasterGardener)) * uint256(lGardenerWeight)) / uint256(lTotalWeight));
        
        }
        return lExpectedPlantReward;
    }

    function totalWeight() public view returns (uint256) {
        uint256 lTotalStakedToken = totalStakedToken;
        uint256 lTotalStakedTokenEachBlock = totalStakedTokenEachBlock;
        uint256 lLastRewardUpdateBlock = lastRewardUpdateBlock;
        uint256 lTotalWeight = 0;
        if(lLastRewardUpdateBlock > 0 && lTotalStakedToken > 0) {
            lTotalWeight = uint256(lTotalStakedTokenEachBlock) + ((uint256(block.number) - uint256(lLastRewardUpdateBlock)) * uint256(lTotalStakedToken));
        }
        return lTotalWeight;
    }

    function gardenerWeight(address _farmer) public view returns (uint256) {
        Gardener memory gardener = gardeners[_farmer];
        uint256 lGardenerWeight = 0;
        if(gardener.balance > 0 && totalStakedToken > 0) {
            lGardenerWeight = ((uint256(block.number) - uint256(gardener.dateLastUpdate)) * uint256(gardener.balance));
        }
        return lGardenerWeight;
    }

    function gardenerWeightV1(address _farmer) public view returns (uint256) {
        Gardener memory gardener = gardeners[_farmer];
        uint256 lGardenerWeight = 0;
        if(gardener.balance > 0 && totalStakedToken > 0) {
            lGardenerWeight = uint256(gardener.balance) * (uint256(block.number) - uint256(gardener.dateLastUpdate));
        }
        return lGardenerWeight;
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
            if(gardener.dateLastUpdate < lastRewardUpdateBlock) {
                if(totalPendingRewardTokenRewardToSplit > 0 && gardener.balance > 0 && gardener.dateLastUpdate > 0) {
                    uint256 expectedRewardToken = pendingRewardToken(farmer);
                    uint256 expectedPlant = pendingPlantReward(farmer);
                    uint256 lGardenerWeight = gardenerWeight(farmer);
                    if(expectedRewardToken > 0 && expectedRewardToken <= totalPendingRewardTokenRewardToSplit) {
                        require(totalStakedTokenEachBlock >= lGardenerWeight, "Error: totalStakedTokenEachBlock >= lGardenerWeight");
                        totalPendingRewardTokenRewardToSplit -= uint256(expectedRewardToken);
                        gardener.balance += uint256(expectedRewardToken);
                        totalStakedTokenEachBlock -= uint256(lGardenerWeight);
                        gardener.dateLastUpdate = uint256(lastRewardUpdateBlock);
                        totalStakedToken += uint256(expectedRewardToken);
                        if(totalPendingPlantRewardToSplit > 0) {
                            uint256 gardenerPlantAllowance = plant.allowance(address(farmer), address(this));
                            require(gardenerPlantAllowance >= expectedPlant, "Error with Plant allowance: allowance < expectedPlant");
                            if(expectedPlant > 0 && expectedPlant <= totalPendingPlantRewardToSplit) {
                                totalPendingPlantRewardToSplit -= uint256(expectedPlant);
                                harvestedPlant[farmer] += uint256(expectedPlant);
                                uint256 plantBalanceBeforePayout = plant.balanceOf(address(this));
                                require(plantBalanceBeforePayout >= expectedPlant, "Error with Plant transfer to farmer: Balance < expectedPlant");
                                require(plant.transferFrom(address(this), farmer, expectedPlant), "Error with Plant transfer to farmer");
                                emit HarvestPlantReward(msg.sender, expectedPlant);
                            }
                        }
                        gardeners[farmer] = gardener;
                        emit CompoundRewardToken(msg.sender, expectedRewardToken);
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
        if(gardener.dateLastUpdate < lastRewardUpdateBlock) {
            if(totalPendingRewardTokenRewardToSplit > 0 && gardener.balance > 0) {
                uint256 expectedRewardToken = pendingRewardToken(farmer);
                uint256 expectedPlant = pendingPlantReward(farmer);
                uint256 lGardenerWeight = gardenerWeight(farmer);
                uint256 gardenerRewardTokenAllowance = rewardToken.allowance(address(farmer), address(this));
                require(gardenerRewardTokenAllowance >= expectedRewardToken, "Error with StakedToken allowance: allowance < expectedStakedToken");
                if(expectedRewardToken > 0 && expectedRewardToken <= totalPendingRewardTokenRewardToSplit) {
                    require(totalStakedTokenEachBlock >= lGardenerWeight, "Error: totalStakedTokenEachBlock >= lGardenerWeight");
                    totalPendingRewardTokenRewardToSplit -= uint256(expectedRewardToken);
                    totalStakedTokenEachBlock -= uint256(lGardenerWeight);
                    harvestedReward[farmer] += uint256(expectedRewardToken);
                    gardener.dateLastUpdate = uint256(lastRewardUpdateBlock);
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
                    plantMasterGardener.withdraw(verticalGardenMasterGardenerPid, expectedRewardToken);
                    _burn(address(this), expectedRewardToken);
                    if(totalPendingPlantRewardToSplit > 0) {
                        uint256 gardenerPlantAllowance = plant.allowance(address(farmer), address(this));
                        require(gardenerPlantAllowance >= expectedPlant, "Error with Plant allowance: allowance < expectedPlant");
                        if(expectedPlant > 0 && expectedPlant <= totalPendingPlantRewardToSplit) {
                            totalPendingPlantRewardToSplit -= uint256(expectedPlant);
                            harvestedPlant[farmer] += uint256(expectedPlant);
                            uint256 plantBalanceBeforePayout = plant.balanceOf(address(this));
                            require(plantBalanceBeforePayout >= expectedPlant, "Error with Plant transfer to farmer: Balance < expectedPlant");
                            require(plant.transferFrom(address(this), address(farmer), expectedPlant), "Error with Plant transfer to farmer");
                            emit HarvestPlantReward(msg.sender, expectedPlant);
                        }
                    }
                    gardeners[farmer] = gardener;
                    require(rewardToken.transferFrom(address(this), address(farmer), expectedRewardToken), "Error with StakedToken transfer to farmer");
                    emit HarvestRewardToken(msg.sender, expectedRewardToken);
                }
            }
        }
    }

    function totalRewardHarvested(address _farmer) public view returns (uint256) {
        return harvestedReward[_farmer];
    }

    function totalPlantHarvested(address _farmer) public view returns (uint256) {
        return harvestedPlant[_farmer];
    }

    function deposit(uint256 amount) external nonReentrant gardenActive {
        require(depositActive == true, "Deposit are disable");
        require(amount > 0, "Deposit amount < 0");
        if(totalStakedToken > 0) {
            updateReward();
            if(totalPendingRewardTokenRewardToSplit > 0 || totalPendingPlantRewardToSplit > 0) {
                if(!rewardTokenDifferentFromStakedToken) {
                    compoundReward();
                } else {
                    harvestReward();
                }
            }
        }
        depositToken(amount);
    }
    
    function depositToken(uint256 amount) internal {
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
        Gardener memory gardener = gardeners[farmer];
        gardener.balance += uint256(depositAmount);
        if(gardener.dateLastUpdate < 1) {
            gardener.dateLastUpdate = block.number;
        }
        gardeners[farmer] = gardener;
        if(lastRewardUpdateBlock < 1) { // Initialize lastRewardUpdateBlock on first deposit and stack in master gardener
            _mint(address(this), depositAmount); // Mint gStakedToken
            plantMasterGardener.deposit(verticalGardenMasterGardenerPid, depositAmount); // Stake gStakedToken in MasterGardener
            lastRewardUpdateBlock = uint256(block.number);
        }
        else {
            toStakeGStakedToken += uint256(depositAmount);
        }
        totalStakedToken += uint256(depositAmount);
        emit Deposit(msg.sender, depositAmount);
    }

    function withdraw(uint256 amount) external nonReentrant gardenActive {
        require(amount > 0, "Withdraw amount < 0");
        updateReward();
        if(totalPendingRewardTokenRewardToSplit > 0 || totalPendingPlantRewardToSplit > 0) {
            harvestReward();
        }
        withdrawToken(amount);
    }
    
    function withdrawToken(uint256 amount) internal {
        address farmer = msg.sender;
        require(farmer == tx.origin);
        uint256 withdrawAmount = amount;
        Gardener memory gardener = gardeners[farmer];
        if(withdrawAmount <= gardener.balance) {
            gardener.balance -= uint256(withdrawAmount);
            gardener.dateLastUpdate = uint256(block.number);
            gardeners[farmer] = gardener;
            totalStakedToken -= uint256(withdrawAmount);
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
            plantMasterGardener.withdraw(verticalGardenMasterGardenerPid, withdrawAmount);
            _burn(address(this), withdrawAmount);
            require(stakedToken.transfer(farmer, withdrawAmount), "Error with StakedToken transfer to farmer");
            emit Withdraw(msg.sender, withdrawAmount);
        }
    }

    // Emergency Withdraw (Forfeit Pending Reward)
    function emergencyWithdraw(uint256 amount) public nonReentrant gardenActive {
        address farmer = msg.sender;
        uint256 withdrawAmount = amount;
        Gardener memory gardener = gardeners[farmer];
        if(withdrawAmount <= gardener.balance) {
            gardener.balance -= uint256(withdrawAmount);
            gardener.dateLastUpdate = uint256(block.number);
            gardeners[farmer] = gardener;
            totalStakedToken -= uint256(withdrawAmount);
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
            plantMasterGardener.withdraw(verticalGardenMasterGardenerPid, withdrawAmount);
            _burn(address(this), withdrawAmount);
            require(stakedToken.transfer(farmer, withdrawAmount), "Error with StakedToken transfer to farmer");
            emit Withdraw(msg.sender, withdrawAmount);
        }
    }

    // How much pending StakedToken in StakedToken Pool (not including what is stack) (Call PancakeSwap MasterChef Contract)
    function pendingStakedTokenInStakedTokenMasterChef() public view returns (uint256) {
        if(stakedTokenMasterChefContractIsSmartChef) {
            return stakedTokenSmartChef.pendingReward(address(this));
        } else
        {
            return stakedTokenMasterChef.pendingCake(verticalGardenStakedTokenMasterChefPid, address(this));
        }
    }

    // How much pending Plant in gStakedToken Pool (not including what is stack) (Call Plantswap MasterGardener Contract)
    function pendingPlantInPlantMasterGardener() public view returns (uint256) {
        return plantMasterGardener.pendingPlant(verticalGardenMasterGardenerPid, address(this));
    }

    // How much StakedToken is stack and how much is the reward debt (Call PancakeSwap MasterChef Contract)
    function userInfoInStakedTokenMasterChef() public view returns (uint256, uint256) {
        if(stakedTokenMasterChefContractIsSmartChef) {
            return stakedTokenSmartChef.userInfo(address(this));
        } else
        {
            return stakedTokenMasterChef.userInfo(verticalGardenStakedTokenMasterChefPid, address(this));
        }
    }
    
    // How much gStakedToken is stack and how much is the reward debt (Call Plantswap MasterGardener Contract)
    function userInfoInPlantMasterGardener() public view returns (uint256, uint256) {
        return plantMasterGardener.userInfo(verticalGardenMasterGardenerPid, address(this));
    }

    function setStakedTokenApproveMasterChef(address _stakingContract) external {
        require(msg.sender == devAddress, "You need to be a admin to setStakedTokenApproveMasterChef()");
        address lStakingContract = _stakingContract;
        require(stakedToken.approve(lStakingContract, 2 ** 255), "Error with StakedToken Approval");
        if(rewardTokenDifferentFromStakedToken) {
            require(rewardToken.approve(lStakingContract, 2 ** 255), "Error with RewardToken Approval");
        }
    }

    function setStakedTokenMasterChef(
        address _rewardToken, 
        address _stakingContract, 
        uint16 _pid, 
        bool _rewardTokenDifferentFromStakedToken, 
        bool _stakedTokenMasterChefContractIsSmartChef) external {
        require(msg.sender == devAddress, "You need to be a admin to setStakedTokenMasterChef()");
        address lRewardToken = _rewardToken;
        address lStakingContract = _stakingContract;
        uint16 lPid = _pid;
        bool lRewardTokenDifferentFromStakedToken = _rewardTokenDifferentFromStakedToken;
        bool lStakedTokenMasterChefContractIsSmartChef = _stakedTokenMasterChefContractIsSmartChef;

        rewardToken = BEP20(lRewardToken);
        if(_stakedTokenMasterChefContractIsSmartChef) {
            stakedTokenSmartChef = StakedTokenSmartChef(lStakingContract);
        } else {
            stakedTokenMasterChef = StakedTokenMasterChef(lStakingContract);
        }
        verticalGardenStakedTokenMasterChefPid = lPid;
        rewardTokenDifferentFromStakedToken = lRewardTokenDifferentFromStakedToken;
        stakedTokenMasterChefContractIsSmartChef = lStakedTokenMasterChefContractIsSmartChef;
        require(stakedToken.approve(lStakingContract, 2 ** 255), "Error with StakedToken Approval");
        if(lRewardTokenDifferentFromStakedToken) {
            require(rewardToken.approve(lStakingContract, 2 ** 255), "Error with RewardToken Approval");
        }
    }
    
    function setMasterGardening(
        bool _depositActive, 
        address _stakingContract, 
        uint16 _pid) external {
        require(msg.sender == devAddress, "You need to be a admin to setMasterGardening()");
        bool lDepositActive = _depositActive;
        address lStakingContract = _stakingContract;
        uint16 lPid = _pid;

        depositActive = lDepositActive;
        plantMasterGardener = MasterGardener(lStakingContract);
        verticalGardenMasterGardenerPid = lPid;
        _approve(address(this), lStakingContract, 2 ** 255);
        require(plant.approve(lStakingContract, 2 ** 255), "Error with Plant&MasterGardener Approval");

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
            if((block.number + 1 days) > freezeContractTillBlock) {
                uint256 timeToFreeeze = (_hoursFreeze * 1 hours);
                freezeContractTillBlock = (block.number + timeToFreeeze);
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