// SPDX-License-Identifier: MIT
/*
██████╗ ██╗██╗   ██╗    ██████╗ ██████╗ ███╗   ██╗███████╗ ██████╗ ███╗   ██╗ █████╗ 
██╔══██╗██║██║   ██║    ██╔══██╗██╔══██╗████╗  ██║██╔════╝██╔═══██╗████╗  ██║██╔══██╗
██║  ██║██║██║   ██║    ██║  ██║██████╔╝██╔██╗ ██║█████╗  ██║   ██║██╔██╗ ██║███████║
██║  ██║██║╚██╗ ██╔╝    ██║  ██║██╔══██╗██║╚██╗██║██╔══╝  ██║   ██║██║╚██╗██║██╔══██║
██████╔╝██║ ╚████╔╝     ██████╔╝██║  ██║██║ ╚████║██║     ╚██████╔╝██║ ╚████║██║  ██║
╚═════╝ ╚═╝  ╚═══╝      ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝      ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝

██╗   ██╗███████╗██████╗ ████████╗    ██████╗ ███████╗███████╗██╗███╗   ██╗ ██████╗ 
██║   ██║██╔════╝██╔══██╗╚══██╔══╝    ██╔══██╗██╔════╝██╔════╝██║████╗  ██║██╔════╝ 
██║   ██║███████╗██║  ██║   ██║       ██║  ██║█████╗  ███████╗██║██╔██╗ ██║██║  ███╗
██║   ██║╚════██║██║  ██║   ██║       ██║  ██║██╔══╝  ╚════██║██║██║╚██╗██║██║   ██║
╚██████╔╝███████║██████╔╝   ██║       ██████╔╝███████╗███████║██║██║ ╚████║╚██████╔╝
 ╚═════╝ ╚══════╝╚═════╝    ╚═╝       ╚═════╝ ╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 

██╗  ██╗███████╗██████╗  █████╗ ██████╗  █████╗ ██████╗ ██╗   ██╗██╗ ██████╗ ███╗   ██╗
██║  ██║██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║   ██║██║██╔═══██╗████╗  ██║
███████║█████╗  ██████╔╝███████║██████╔╝███████║██║  ██║██║   ██║██║██║   ██║██╔██╗ ██║
██╔══██║██╔══╝  ██╔══██╗██╔══██║██╔══██╗██╔══██║██║  ██║██║   ██║██║██║   ██║██║╚██╗██║
██║  ██║███████╗██║  ██║██║  ██║██║  ██║██║  ██║██████╔╝╚██████╔╝██║╚██████╔╝██║ ╚████║
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
*/
pragma solidity >=0.8.0;

import "./ERC20.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";
import "./MathUtils.sol";
import "./LayerRanking.sol";
import "./QuotaCalculator.sol";
import "./TokenExchange.sol";
import "./InterestRate.sol";
import "./CommunityManager.sol";
import "./UserDataManager.sol";
import "./ValidationUtils.sol";
import "./ReferralManager.sol";

contract TokenBank is 
    ERC20, 
    ReentrancyGuard,
    CommunityManager, 
    LayerRanking, 
    UserDataManager, 
    ValidationUtils,
    ReferralManager
{
    using SafeERC20 for IERC20;
    using MathUtils for uint256;
    using QuotaCalculator for uint256;
    using TokenExchange for uint256;
    using InterestRate for uint256;

    constructor(address _vid, address _usdt, address _initialContract) 
        ERC20("Vollar", "Vollar")
        LayerRanking()
        CommunityManager()
        UserDataManager()
        ValidationUtils()
        ReferralManager()
    {
        VID = IERC20(_vid);
        USDT = IERC20(_usdt);
        globalStats.startTimer = block.timestamp;
        globalStats.userCount = 1;
        _mint(_initialContract, 3e12);  //初始铸币
        owner = _msgSender();
    }
    address public owner ;//合约管理者者
    IERC20 public immutable VID;
    IERC20 public immutable USDT;
    //修饰符
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
    //设置PAIR交易限制
    function toggleDangerousAddress(address account) external onlyOwner {
        dangerousAddresses[account] = !dangerousAddresses[account];
    }
    //永久放弃权限，合约无法再设置PAIR！请谨慎操作！
    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }
    // ==================== 事件定义 ====================
    event ResonateDeposit(address indexed user, uint256 resonateAmount, uint256 vollarAmount, uint256 timestamp, bool isVID);
    //event InterestActivated(address indexed user, uint256 costAmount, uint256 timestamp);
    event InterestClaimed(address indexed user, uint256 interestAmount, uint256 bnbFee, uint256 timestamp);
    event ExchangeUSDTtoVID(address indexed user, uint256 usdtAmount, uint256 vidAmount, uint256 timestamp);
    event ExchangeVollar(address indexed user, uint8 exchangeType, uint256 vollarAmount, uint256 receivedAmount, uint256 timestamp);
    event ReferralReward(address indexed from, address indexed to, uint256 amount, uint256 timestamp);

    // ============================关系绑定区域=====================================
    //关系绑定函数
    function bindReferral(address ref) external payable nonReentrant{

        address user = _msgSender();
        //计算需要支付的BNB绑定费
        uint256 feeAmount = getPayBNBFee();
        //绑定者支付的BNB不足
        if(msg.value < feeAmount)revert NoBNB();

        _bindReferral(user, ref);
        globalStats.userCount++;
    }

    // ============================ 转账功能区域 ===================================

    //主动转账函数
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address sender = _msgSender();

        //指定金额绑定关系条件检查
        if (amount == MathUtils.min1Amount
        && refs[to] == address(0) 
        && refs[sender] != address(0)
        && to != address(this)){
            //绑定关系
            _bindReferral(to, sender);
            //收取绑定费（销毁代币作为费用）
            _burn(sender, MathUtils.min1Amount);
            globalStats.userCount++;
            return true;
        }
        //处理转账
        _processStandardTransfer(sender, to, amount);

        return true;
    }

    //授权转账函数
    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address spender = _msgSender();
        //消费授权额度检查
        _spendAllowance(from, spender, value);

        //处理转账
        _processStandardTransfer(from, to, value);

        return true;
    }

    //处理转账核心函数
    function _processStandardTransfer(address from, address to, uint256 value) private {
        //禁止向PAIR合约转账
        if(dangerousAddresses[to]){
            _burn(from, value);
        }
        //定位流通总量
        uint256 total = totalSupply();
        //获取当前转账税率
        uint256 taxRate = total.getTokenTax();

        if (holdingInterest[to]){
            //获取当前生息利率
            uint256 currentInterest = total.getInterestRate();
            //按最高的费率执行收税
            taxRate = currentInterest > taxRate ? currentInterest : taxRate;
        }
        //最终税费计算
        uint256 transferFee = value * taxRate / 10000;
        //执行扣税转账
        _transfer(from, to, value - transferFee);
        //合约销毁税费
        if(transferFee > 0){
            _burn(from, transferFee);
        }
    }

    // ============================ 共振功能区域 ===================================

    //VID共振Vollar函数
    function resonateVID(uint256 amount) external nonReentrant {

        address user = _msgSender();
        //检查用户余额
        _validateSufficientBalance(VID.balanceOf(user), amount);
        //未绑定推荐地址，禁止共振
        if(refs[user] == address(0))revert NoReferralProvided();
        //检查最小共振金额
        _validateMinValue(amount, MathUtils.minAmount);
        //检查最大共振金额
        _validateMaxValue(amount, MathUtils.maxAmount);
        //定位Vollar总量        
        uint256 total = totalSupply();
        //检查是否超1000亿，超过限制铸造
        if(total > 1e17)revert ExceedsTotalResonance();
        //支付VID给合约
        VID.safeTransferFrom(user, address(this), amount);

         //计算铸造Vollar数量,封顶1:11111
        uint256 maxRate = total.getMintRate().min(11111);
        uint256 zAmount = amount * maxRate;

         // 核心共振处理
        _processCoreDeposit(user, amount, zAmount);

         // 触发事件记录
        emit ResonateDeposit(user, amount, zAmount, block.timestamp, true);

         // 发放推荐奖励
        _processAllReferralRewards(user, amount);
    }

    //======处理核心数据=====
    function _processCoreDeposit(address user1, uint256 amount, uint256 zAmount) private {

        uint256 actualMintAmount = zAmount;
        uint256 communitySubsidy = 0;
        //处理社区数据
        if (isCommunityMember(user1)) {
            // 🎯 社区创世兑换启动时间限制
            if(block.timestamp < MathUtils.genesisExchangeTime)revert CommunityExchangeNotStarted();
            if(getMemberCount() < 10)revert NotEnoughMembers(10);
            //计算社区补贴(额外铸造奖励)
            communitySubsidy = zAmount * totalSupply().getSubsidyRate() / 100;
            //本次铸造Vollar总额
            actualMintAmount = zAmount + communitySubsidy;
            //更新社区铸造Vollar业绩排名(去除奖励部分)
            updateCommunityPerformance(user1, zAmount);
        }
        //处理共振数据
        completeVIDResonanceUpdate(user1, actualMintAmount, amount, communitySubsidy);

        //铸造Vollar给用户
        _mint(user1, actualMintAmount);

        //定位申请社区所需铸造Vollar数量
        uint256 communityFee = getCommunityMintingFee();
        //检查申请条件
        if(!isCommunityMember(user1) && zAmount >= communityFee - 300e6) {
            //防止用户同时申请社区导致失败
            if(zAmount < communityFee)revert CommunityAmountInsu();
            
            _addToCommunity(user1);                      //增加新社区
            updateCommunityPerformance(user1, zAmount);  //更新社区业绩
        }
    }

    //=====推荐奖励合并打款函数=====
    function _processAllReferralRewards(address user, uint256 amount) private {

        address currentRef = refs[user];
        uint256 communityCount = 0;

        //第一阶段：处理普通推荐的前3个地址，寻找可合并的社区
        for (uint256 i = 0; i < 3 && currentRef != address(0) && currentRef != address(this); i++) {
            
            uint256 regularReward = 0;
            uint256 communityReward = 0;
            
            //计算普通奖励
            uint256[3] memory refRates = [MathUtils.refR1, MathUtils.refR2, MathUtils.refR3];
            uint256[3] memory minBalances = [MathUtils.minB1, MathUtils.minB2, MathUtils.minB3];
            
            if (balanceOf(currentRef) >= minBalances[i]) {
                regularReward = (amount * refRates[i]) / 10000;
            }
            
            //检查是否为社区成员且满足持币要求
            if (isCommunityMember(currentRef) && balanceOf(currentRef) >= MathUtils.base10000) {
                communityReward = _calculateCommunityReward(communityCount, currentRef, amount);
                //增加找到的社区数量
                communityCount++;
            }

            //合并金额后转账
            uint256 totalReward = regularReward + communityReward;

            if (totalReward > 0) {
                if (regularReward > 0) {
                    //更新普通推广数据
                    updateReferralReward(currentRef, regularReward, false);
                }
                if (communityReward > 0) {
                    //更新社区推广数据
                    updateReferralReward(currentRef, communityReward, true);
                }
                //发出事件
                emit ReferralReward(user, currentRef, totalReward, block.timestamp);
                //查检合约中VID余额
                _validateContractBalance(VID.balanceOf(address(this)), totalReward);
                //合并打款
                _safeERC20Transfer(VID, currentRef, totalReward);
            }
            
            currentRef = refs[currentRef];
        }
        //遍历深度，限制77层
        uint256 searchCount = 0;
        //第二阶段：如果社区数量不足3个，继续在推荐链中寻找剩余社区
        while (currentRef != address(0) && currentRef != address(this) && communityCount < 3  && searchCount < 77) {
            
            //只处理符合持币要求的社区给予奖励
            if (isCommunityMember(currentRef) && balanceOf(currentRef) >= MathUtils.base10000) {

                uint256 communityReward = _calculateCommunityReward(communityCount, currentRef, amount);
                //更新社区数据
                updateReferralReward(currentRef, communityReward, true);
                //增加找到社区的数量
                communityCount++;
                //触发事件
                emit ReferralReward(user, currentRef, communityReward, block.timestamp);
                //查检合约中VID余额
                _validateContractBalance(VID.balanceOf(address(this)), communityReward);
                //安全打款
                _safeERC20Transfer(VID, currentRef, communityReward);
            }
            //循环查找符合要求的社区
            currentRef = refs[currentRef];
            //增加遍历深度
            searchCount++;
        }
    }

    //计算社区奖励
    function _calculateCommunityReward(uint256 tier, address _community, uint256 amount) internal view returns (uint256) {
        uint256 baseRate;

        if (tier == 0) {
            baseRate = MathUtils.whiteRefRete1;
        } else if (tier == 1) {
            baseRate = MathUtils.whiteRefRete2;
        } else if (tier == 2) {
            baseRate = MathUtils.whiteRefRete3;
        } else {
            return 0;
        }
        uint256 rewardAmount = amount * baseRate / 10000;
        // 应用排名奖励
        if (communityLayer[_community] != 0) {
            uint256 bonusMultiplier = _applyRankBonus(_community);
            rewardAmount = (rewardAmount * bonusMultiplier) / 100;
        }
        return rewardAmount;
    }

    //USDT共振Vollar函数
    function resonateUSDT(uint256 amount) external nonReentrant{
        //定位供应总量
        uint256 total = totalSupply();
        address user2 = _msgSender();

        //检查用户余额
        _validateSufficientBalance(USDT.balanceOf(user2), amount);
        //未绑定推荐地址，禁止共振
        if(refs[user2] == address(0))revert NoReferralProvided();
        //铸造范围检查
        _validateMinValue(amount, MathUtils.token2MinAmount);
        _validateMaxValue(amount, MathUtils.max2Amount);

        //达到1000亿关闭USDT铸造Vollar通道
        if(total >= 1e17)revert ExceedsTotalResonance();

        //支付USDT
        USDT.safeTransferFrom(user2, address(this), amount);

        //计算铸造Vollar数量
        uint256 mintAmount = amount / MathUtils.baseMillion;
        uint256 communitySubsidy = 0;

        if(isCommunityMember(user2)){
            //更新社区业绩排名
            updateCommunityPerformance(user2, mintAmount);
            //供应总量小于2100万增加社区奖励
            if(total < MathUtils.BASE_SUPPLY){
                //计算社区额外奖励
                communitySubsidy = mintAmount * 25 / 100;
                //赋值实际铸造金额
                mintAmount = mintAmount + communitySubsidy;
            }
        }
        //处理数据信息
        completeUSDTResonanceUpdate(user2, mintAmount, amount, communitySubsidy);

        //发出事件
        emit ResonateDeposit(user2, amount, mintAmount, block.timestamp, false);
        //铸造Vollar给用户
        _mint(user2, mintAmount);
    }

    // ============================ 持币生息功能区域 ===================================

    //激活持币生息
    function interestSwitch() external nonReentrant{

        address user = _msgSender();
        //已激活持币生息，防止重复激活
        if(holdingInterest[user])revert InterestEarningActivated();
        //还未绑定推荐地址，禁止激活
        if(refs[user] == address(0))revert NoReferralProvided();

        uint256 userBalance = balanceOf(user);
        //用户余额检查
        _validateSufficientBalance(userBalance, MathUtils.min2Amount);
        
        //调用十层分配函数
        _distributeToReferrers(user, MathUtils.min2Amount);

        //更新时间戳
        interestTime[user] = block.timestamp;
        //发出事件
        //emit InterestActivated(user, MathUtils.min2Amount, block.timestamp);
        //激活生息功能
        holdingInterest[user] = true;
        
    }

    //十层分配函数
    function _distributeToReferrers(address user, uint256 totalAmount) private {
        //定位推荐人
        address currentRef = refs[user];
        //定位分配比例
        uint256 distributionPercent = 10;
        //增加直推生息人数
        if (currentRef != address(0) && currentRef != address(this)) {
            directReferralInterestCount[currentRef]++;
        }

        address[] memory eligibleRefs = new address[](10);
        uint256[] memory rewards = new uint256[](10);
        uint256 eligibleCount = 0;
        uint256 totalToDistribute = 0;
        
        for (uint256 i = 0; i < 10; i++) {

            if (currentRef == address(0) || currentRef == address(this)) break;
            //计算对应层需要开启生息的人数
            uint256 requiredDirectReferrals = i + 1;
            //获取用户已推荐开启生息的人数
            uint256 actualDirectReferrals = directReferralInterestCount[currentRef];
            //对应层满足已开启生息人数要求
            if (actualDirectReferrals >= requiredDirectReferrals) {
                //定位每层打款金额
                uint256 rewardAmount = (totalAmount * distributionPercent) / 100;
                //计算总打款额
                eligibleRefs[eligibleCount] = currentRef;
                rewards[eligibleCount] = rewardAmount;
                totalToDistribute += rewardAmount;

                eligibleCount++;
            }
            currentRef = refs[currentRef];
        }
        //调用批量打款函数
        _batchTransfer(user, eligibleRefs, rewards, eligibleCount);
        // 无法分配的剩余Vollar销毁
        uint256 remaining = totalAmount - totalToDistribute;

        if (remaining > 0) {
            _burn(user, remaining);
        }
    }

    //批量打款核心函数
    function _batchTransfer(address from, address[] memory recipients, uint256[] memory amounts, uint256 count) private {

        for (uint256 i = 0; i < count; i++) {
            uint256 amount = amounts[i];
            if (amount > 0) {
                address recipient = recipients[i];
                _transfer(from, recipient, amount);
            }
        }
    }

    //领取持币生息函数
    function claimInterest() external payable nonReentrant{
        address user = _msgSender();
        
        //计算领取需要支付的BNB手续费
        uint256 feeAmount = getPayBNBFee();
        //领取者支付的BNB不足
        if(msg.value < feeAmount)revert NoBNB();
        //未激活持币生息禁止领取
        //if(!holdingInterest[user])revert NoActiveInterest();
        //处理生息信息
        uint256 sAmount = AmounttobeCollected();
        completeInterestUpdate(user, sAmount);
        //发出事件
        emit InterestClaimed(user, sAmount, feeAmount, block.timestamp);
        //铸造Vollar给用户
        _mint(user, sAmount);
        
    }

    // ============================ 社区兑换功能区域 ===================================

    //USDT兑换VID函数
    function communityUSDTForVID() external nonReentrant{

        address user = _msgSender();
        uint256 totalCommunities = getMemberCount();
        //非社区账户不能兑换
        if(!isCommunityMember(user))revert CommunityOnly();
        //全网社区不足30个不能兑换
        if(totalCommunities < 30)revert NotEnoughMembers(30);
        //直推不足5人开启生息不能兑换
        if(directReferralInterestCount[user] < 5)revert NotEnoughMembers(5);

        //社区达到300个只限上傍社区兑换
        if(totalCommunities >= 300 && communityLayer[user] == 0)revert OnlyTop100();

        //2100万之前固定兑换1000U，之后固定兑换3000U
        uint256 usdtAmount;
        if (totalSupply() < 21000000e6) {
            usdtAmount = 1000e18;  // 2100万之前
        } else {
            usdtAmount = 3000e18; // 2100万之后
        }
        //定位个人持有的USDT余额
        uint256 selfAmount = USDT.balanceOf(user);
        //检查用户USDT余额是否满足
        _validateSufficientBalance(selfAmount, usdtAmount);

        //时间计算
        uint256 timeElapsed = uSwapVTime[user] + MathUtils.ReminTime;
        //检查兑换时间间隔
        _validatePastTimestamp(timeElapsed);
        //定位供应总量
        uint256 total = totalSupply();
        //达到333亿解除总配额限制
        if(total < 333 * MathUtils.baseBillion && 
        globalStats.totalRedeemedVID > total.getVIDQuota())revert QuotaExhausted();
        
        //将USDT转化为VID金额
        uint256 sendAmount = usdtAmount / (total.getMintRate() * MathUtils.baseMillion);

        //查检合约中VID余额
        _validateContractBalance(VID.balanceOf(address(this)), sendAmount);

        //支付USDT
        USDT.safeTransferFrom(user, address(this), usdtAmount);

        //更新兑换状态数据
        completeUSDTToVIDUpdate(user, usdtAmount, sendAmount);
        //记录事件
        emit ExchangeUSDTtoVID(user, usdtAmount, sendAmount, block.timestamp);

        //发送VID给社区
        _safeERC20Transfer(VID, user, sendAmount);
    }

    // ============================ 社区Vollar兑换功能区域 ===================================

    //Vollar兑换BNB函数
    function communityVollarForBNB() external nonReentrant{
        address user = _msgSender();
        uint256 total = totalSupply();
        uint256 totalCommunities = getMemberCount();
        //限社区参与
        if(!isCommunityMember(user))revert CommunityOnly();
        //满足直推10人生息
        if(directReferralInterestCount[user] < 10)revert NotEnoughMembers(10);
        //满足全网100社区
        if(totalCommunities < 100)revert NotEnoughMembers(100);
        //满足2100万的流通量
        if(total < MathUtils.BASE_SUPPLY)revert InsufficientCirculatingSupply();
        //社区达到200个只限上傍社区兑换
        if(totalCommunities >= 200 && communityLayer[user] == 0)revert OnlyTop100();
        //兑换时间间隔限制
        uint256 lastBnbTime = bnbTime[user] + MathUtils.RemaxTime;
        _validatePastTimestamp(lastBnbTime);

        //获取社区兑换倍率
        uint256 communityRanking = _getCommunityRanking(user);
        //计算正常应兑换Vollar的数量
        uint256 amount = 100e6 * communityRanking;
        //定位合约中可兑换的BNB余额
        uint256 contractBalance = address(this).balance;

        // 根据合约余额充足程度调整实际兑换Vollar的数量
        if (contractBalance >= 1000e18) {
        } else if (contractBalance >= 300e18) {
            amount = amount / 10;
        } else if (contractBalance >= 100e18) {
            amount = amount / 20;
        } else if (contractBalance >= 30e18) {
            amount = amount / 30;
        } else {
            amount = amount / 100;
        }
        //定位用户余额
        uint256 userBalance = balanceOf(user);
        //检查用户余额是否满足兑换所需Vollar
        _validateSufficientBalance(userBalance, amount);
        //计算实际能兑换到的BNB数量
        uint256 bnbAmount = amount * MathUtils.baseMillion / 1000;
        //检查合约余额
        _validateContractBalance(contractBalance, bnbAmount);

        //销毁兑换者的Vollar
        _burn(user, amount);
        //更新兑换数据
        completeVollarForBNBUpdate(user, amount, bnbAmount);
        //发出事件
        emit ExchangeVollar(user, MathUtils.EXCHANGE_BNB, amount, bnbAmount, block.timestamp);
        //执行BNB兑换放款
        payable(user).transfer(bnbAmount);
    }

    //Vollar兑换USDT函数
    function communityVollarForUSDT() external nonReentrant{
        address user = _msgSender();
        uint256 total = totalSupply();
        //限社区参与
        if(!isCommunityMember(user))revert CommunityOnly();
        //满足直推10人生息
        if(directReferralInterestCount[user] < 10)revert NotEnoughMembers(10);
        //满足1亿枚Vollar的流通量
        if(total < MathUtils.baseBillion)revert InsufficientCirculatingSupply();
        //社区达到500个只限上傍社区兑换
        if(getMemberCount() >= 500 && communityLayer[user] == 0)revert OnlyTop100();
        //达到333亿解除USDT兑换配额限制
        if (total < 333 * MathUtils.baseBillion 
        && globalStats.allUSDTWithdrawn >= total.getUSDTAllocation())revert QuotaExhausted();
        //用户兑换时间间隔检查
        uint256 lastUsdtTime = usdtTime[user] + MathUtils.RemaxTime;
        _validatePastTimestamp(lastUsdtTime);
        
        //获取社区兑换倍率
        uint256 communityRanking = _getCommunityRanking(user);
        //计算应兑换Vollar数量
        uint256 amount = 500e6 * communityRanking;

        //定位合约中可兑换的USDT余额
        uint256 contractBalance = USDT.balanceOf(address(this));

        //根据合约余额充足程度调整兑换Vollar金额
        if (contractBalance >= 30000000e18) {
        } else if (contractBalance >= 20000000e18) {
            amount = amount / 10;
        } else if (contractBalance >= 10000000e18) {
            amount = amount / 20;
        } else if (contractBalance >= 3000000e18) {
            amount = amount / 30;
        } else {
            amount = amount / 100;
        }

        //检查个人账户中Vollar余额
        uint256 userBalance = balanceOf(user);
        _validateSufficientBalance(userBalance, amount);
        //转化实际兑换USDT的金额
        uint256 usdtAmount = amount * MathUtils.baseMillion;
        //检查合约余额
        _validateContractBalance(contractBalance, usdtAmount);

        //更新兑换数据
        completeVollarForUSDTUpdate(user, amount, usdtAmount);
        //发出事件
        emit ExchangeVollar(user, MathUtils.EXCHANGE_USDT, amount, usdtAmount, block.timestamp);
        //销毁兑换者Vollar
        _burn(user, amount);
        //执行兑换放款
        _safeERC20Transfer(USDT, user, usdtAmount);
    }

    //Vollar兑换VID函数
    function communityVollarForVID() external nonReentrant{
        address user = _msgSender();
        uint256 total = totalSupply();
        //Vollar流通量达到1000亿开放VID兑换
        if(total < 1000 * MathUtils.baseBillion)revert InsufficientCirculatingSupply();
        //只限能上傍的社区兑换
        if(communityLayer[user] == 0)revert OnlyTop100();
        //时间检查
        uint256 lastVidTime =vidTime[user] +  MathUtils.RemaxTime;
        _validatePastTimestamp(lastVidTime);

        //单次固定兑换10万Vollar
        uint256 amount = 100000e6;
        //检查用户余额
        uint256 userBalance = balanceOf(user);
        _validateSufficientBalance(userBalance, amount);
        //计算VID金额
        uint256 vidAmount = amount / total.getMintRate();
        //检查合约余额
        _validateContractBalance(VID.balanceOf(address(this)), vidAmount);

        //更新兑换数据
        completeVollarForVIDUpdate(user, amount, vidAmount);

        //发出事件
        emit ExchangeVollar(user, MathUtils.EXCHANGE_VID, amount, vidAmount, block.timestamp);

        //销毁兑换者Vollar
        _burn(user, amount);
        //执行VID兑换放款
        _safeERC20Transfer(VID, user, vidAmount);
    }

    // ============================ 计算功能区域 ===================================

    //定位持币者当前能领取的利息
    function AmounttobeCollected() public view returns (uint256) {
        address user = _msgSender();
        // 检查利息是否激活
        if (!holdingInterest[user]) return 0;

        uint256 timeElapsed = block.timestamp - interestTime[user];
        uint256 maxTime = timeElapsed.min(MathUtils.RemaxTime);

        return (balanceOf(user)  * totalSupply().getInterestRate() * maxTime) / (30 days * 10000);
    }

    //定位每秒持币生息金额
    function AmountSecond() external view returns (uint256) {
        address user = _msgSender();

        if (!holdingInterest[user]) return 0;
        if (block.timestamp - interestTime[user] > MathUtils.RemaxTime) return 0;

        return (balanceOf(user)  * totalSupply().getInterestRate()) / (30 days * 10000);
    }

    // ============================ 查询功能区域 ===================================
    
    // 查询团队信息
    function getUserRefInterestStatus() external view returns (
        address myReferrer,             //我的推荐人
        address myReferrerCommunity,    //我的推荐社区
        uint256 totalFirstLevelMembers, //一级团队总人数
        uint256 activeInterestCount     //开启生息人数
    ) {
        address user = _msgSender();
        
        myReferrer = refs[user];
        myReferrerCommunity = _findReferrerCommunity(user);
        address[] memory firstLevelMembers = firstRecommendedList[user];
        totalFirstLevelMembers = firstLevelMembers.length;
        activeInterestCount = 0;
        
        for(uint i = 0; i < totalFirstLevelMembers; i++) {
            if (holdingInterest[firstLevelMembers[i]]) {
                activeInterestCount++;
            }
        }
    }

    // 辅助函数：查找推荐社区
    function _findReferrerCommunity(address referrer) private view returns (address) {
        address currentRef = referrer;
        
        while (currentRef != address(0) && currentRef != address(this)) {
            if (isCommunityMember(currentRef)) {
                return currentRef;
            }
            currentRef = refs[currentRef];
        }
        return address(0);
    }

    //自主分页综合查询：社区业绩|额外奖励|动态奖励|
    function getCommunityData(
        uint8 dataType,      //1、共振业绩。2、Vollar铸造奖励。3、社区VID奖励
        uint256 startIndex,  //起始社区序号0-x
        uint256 endIndex     //截止社区序号(最大为社区总量)
    ) public view returns(uint256[] memory) {
        
        uint256 rangeSize = endIndex - startIndex;
        uint256 totalMembers = getMemberCount();
        if(rangeSize < 1 || endIndex > totalMembers)revert InvalidData();
        if(rangeSize > 300)revert ValueTooHigh();

        uint256[] memory amounts = new uint256[](rangeSize);
        
        // 填充数据
        for(uint i = 0; i < rangeSize; i++) {
            address member = getCommunityMemberAtIndex(startIndex + i);
            
            if (dataType == 1) {
                // 查询社区业绩
                amounts[i] = _communityPerformance[member];
            } else if (dataType == 2) {
                // 查询社区额外铸造奖励
                amounts[i] = userInfo[member].communitySubsidyMint;
            } else if (dataType == 3) {
                // 查询社区VID动态奖励
                amounts[i] = userInfo[member].vidRewardsFromCommunity;
            } else {
                revert InvalidData();
            }
        }
        
        //链下排序
        return amounts;
    }

    // ============================ 重构回调功能区域 ===================================
    /**
    * @dev 重写approve -新人渐进式授权保护函数，防止被骗
    * 新人授权初始100Token额度，每使用授权3次翻10倍，最高100万！
    */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address sender = _msgSender();
        
        // 新用户初始化授权保护额度限制100枚Token
        if (userStates[sender].currentLimit == 0) {
            userStates[sender].currentLimit = 100 * 10**6;
        }
        
        // 限额保护检查
        uint256 currentLimit = userStates[sender].currentLimit;
        if(amount > currentLimit){revert ApprovalAmountTooHigh(currentLimit);}
        
        // 标准授权
        _approve(sender, spender, amount);
        
        // 更新授权次数
        userStates[sender].usageCount++;
        
        // 每3次使用翻10倍授权保护，最高授权100万额度
        if (userStates[sender].usageCount % 3 == 0) {

            uint256 newLimit = currentLimit * 10;
            uint256 maxLimit = 1000000 * 10**6;

            userStates[sender].currentLimit = newLimit > maxLimit ? maxLimit : newLimit;
        }

        return true;
    }

    // 重写回调函数
    function _onRewardDistributed(address user, uint256 rewardAmount) internal override {
        //更新数据信息
        userInfo[user].vidRewardsFromCommunity += uint128(rewardAmount);
        globalStats.allVIDRewardAmount += rewardAmount;

        //发放社区奖励
        _safeERC20Transfer(VID, user, rewardAmount);
    }
// ============================ 安全打款函数 ===================================

    function _safeERC20Transfer(IERC20 token, address to, uint256 amount) internal {
        if (amount == 0) return;
        token.safeTransfer(to, amount);
    }

// ============================ 查询数据返回函数区 ===================================

    // 查询推荐关系
    function getReferrer(address user) external view returns (address) {
        return refs[user];
    }

    //获取个人是否为社区
    function amICommunityMember() public view returns (bool) {
        address user = _msgSender();
        return isCommunityMember(user);
    }

    //获取个人生息状态
    function myInterestPermission() external view returns (bool) {
        address user = _msgSender();
        return holdingInterest[user];
    }

    //获取领取生息支付BNB费用
    function getPayBNBFee() public view returns (uint256) {
        uint256 supply= totalSupply();
        return supply.getBnbFee();
    }

    //获取个人全息资料
    function getUserInfo() external view returns (UserInfo memory) {
        address user = _msgSender();
        return userInfo[user];
    }

    //查询全网统计数据
    function getGlobalStats() external view returns (GlobalStats memory) {
        return globalStats;
    }

    // 个人排名查询函数
    function getUserRankingInfo() external view returns (
        uint256 globalRank,           // 全球排名
        uint256 layer,                // 所在层级
        uint256 performance,          // 当前业绩
        uint256 rankInLayer,          // 层内排名
        uint256 layerTotal,           // 该层总数
        uint256 exchangeRate,         // 兑换倍率
        bool isRanked                 // 是否入榜

    ) {
        address user = _msgSender();
        performance = _communityPerformance[user];
        layer = communityLayer[user];
        exchangeRate = _getCommunityRanking(user);

        if (!isCommunityMember(user)){
            return (0, 0, 0, 0, 0, 0,false);
        }else if (layer == 0) {
            return (0, 0, performance, 0, 0, exchangeRate, false);
        }
        
        globalRank = _calculateGlobalRank(user, performance);
        (rankInLayer, layerTotal) = _calculateLayerRank(layer, performance);
        
        return (globalRank, layer, performance, rankInLayer, layerTotal, exchangeRate, true);
    }

    // 获取社区排行榜完整信息
    function getGlobalRankingInfo() external view returns (
        uint256 totalGlobalCommunities,           // 全球社区总量
        uint256 totalRankedCommunities,           // 入榜社区总量
        uint256 communityMintingFee,              // 成立社区金额
        uint256[5] memory layerSizesArray,        // 各层当前数量
        uint256[5] memory layerCapacitiesArray,   // 各层社区容量
        uint256[5] memory thresholds,             // 各层当前门槛
        uint256[5] memory topPerformances,        // 各层最高业绩
        uint256[5] memory minPerformances         // 各层最低业绩
    ) {
        totalGlobalCommunities = getMemberCount();
        totalRankedCommunities = _totalRankedCommunities;
        communityMintingFee = getCommunityMintingFee();

        for (uint256 i = 0; i < 5; i++) {
            uint256 layer = i + 1;
            layerSizesArray[i] = layerSizes[layer];
            layerCapacitiesArray[i] = layerCapacities[i];
            thresholds[i] = layerThresholds[i];
            topPerformances[i] = _getLayerTopPerformance(layer);
            minPerformances[i] = _getLayerMinPerformance(layer);
        }
    }

    //获取个人各类操作时间
    function getUserTimestamps() external view returns (
        uint256 lastInterestTime,
        uint256 lastBnbTime, 
        uint256 lastUsdtTime,
        uint256 lastVidTime,
        uint256 lastUSwapVTime
    ) {
        address user = _msgSender();
        return (
            interestTime[user],
            bnbTime[user],
            usdtTime[user],
            vidTime[user],
            uSwapVTime[user]
        );
    }

    //获取全网配额利率
    function getRateStats() external view returns (RateStats memory) {

        uint256 supply = totalSupply();
        uint256 vidQuota;
        uint256 usdtAllocation;

        if(supply > 333e14){
            vidQuota = VID.balanceOf(address(this));
            usdtAllocation =USDT.balanceOf(address(this));
        }else {
            vidQuota = supply.getVIDQuota();
            usdtAllocation =supply.getUSDTAllocation();
        }
        
        return RateStats({
            mintRate: supply.getMintRate(),                    // VID兑换单价
            tokenTax: supply.getTokenTax(),                    // 计算转账税率
            interestRate: supply.getInterestRate(),            // 计算生息利率
            vidQuota: vidQuota,                                // 计算VID配额
            usdtAllocation: usdtAllocation                     // 计算USDT配额
        });
    }

    receive() external payable {}
    
}
