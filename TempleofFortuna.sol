// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * ████████╗███████╗███╗   ███╈██████╗██╗      ███████╗    ███████╗ ██████╗ ██████╗ ████████╗██╗   ██╗███╗   ██╗ █████╗ 
 * ╚══██╔══╝██╔════╝████╗ ████╈█╔════╝██║      ██╔════╝    ██╔════╝██╔═══██╗██╔══██╗╚══██╔══╝██║   ██║████╗  ██║██╔══██╗
 *    ██║   █████╗  ██╔████╔██╈████╗  ██║      █████╗      █████╗  ██║   ██║██████╔╝   ██║   ██║   ██║██╔██╗ ██║███████║
 *    ██║   ██╔══╝  ██║╚██╔╝██╈█╔══╝  ██║      ██╔══╝      ██╔══╝  ██║   ██║██╔══██╗   ██║   ██║   ██║██║╚██╗██║██╔══██║
 *    ██║   ███████╗██║ ╚═╝ ██╈██████╗███████╗ ███████╗    ██║     ╚██████╔╝██║  ██║   ██║   ╚██████╔╝██║ ╚████║██║  ██║
 *    ╚═╝   ╚══════╝╚═╝     ╚═╚══════╝╚══════╝ ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝
 * 
 * @title Temple of Fortuna - 命运女神圣殿
 * @dev 信众在此质押信仰，祭司定时开启金库，公平分配VID福报
 * 
 * 🏛️ 圣殿架构：
 * 
 *      信众
 *        ↓ 质押信仰
 *   ┌─────────────┐
 *   │ 命运圣殿     │ ← 祭司每隔24小时
 *   │ (此合约)     │   开启命运金库
 *   └─────────────┘
 *        ↓ 分发福报        ↑ 转移VID福报
 *      信众               ┌─────────────┐
 *                         │ 命运金库    │
 *                         │ (Purse合约) │
 *                         └─────────────┘
 * 
 * 📜 神圣契约体系：
 * 1. 信众 → 圣殿：质押信仰代币VDS
 * 2. 金库 → 圣殿：积累24小时福报VID
 * 3. 圣殿 → 信众：按信仰比例分发VID福报
 * 4. 信众 ← 圣殿：随时取回信仰VDS
 * 
 * ⚖️ 公平原则：
 * - 信仰越多，福报越多
 * - 每24小时开启一次金库
 * - 福报按信仰比例实时计算
 * - 信众可随时领取福报并消耗5%的VDS
 */

// 信仰代币接口
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IPurseOfFortuna {
    function openThePurse() external returns (uint256);
}

import "./ReentrancyGuard.sol";

// ============= 主合约 =============

contract TempleOfFortuna is ReentrancyGuard{
    // ============= 常量定义 =============
    
    /**
     * @notice 解押等待期：3天
     * @dev 用户发起解押后需要等待3天才能提取代币
     */
    uint256 public constant UNSTAKE_LOCK_PERIOD = 3 days;
    //开启分红最低质押 888 枚VDS(rewardToken)
    uint256 public constant MIN_STAKE_FOR_DIVIDENDS = 888 * 10**8;
    //用户每次质押解押最低0.01VDS
    uint256 public constant MIN_STAKE_AMOUNT = 0.01 * 10**8;
    //触发分红间隔时间
    uint256 public constant DISTRIBUTION_INTERVAL = 24 hours;
    
    // ============= 数据结构 =============
    
    /**
     * @dev 用户信息结构
     * @param amount 当前质押的代币数量
     * @param pendingAmount 待领取奖励金额
     * @param rewardDebt 已计算的奖励债务（用于计算待领取奖励）
     * @param totalRewardDistributed 累计领取分红总额
     */
    struct UserInfo {
        uint256 amount;
        uint256 pendingAmount;
        uint256 rewardDebt;
        uint256 totalRewardDistributed;
    }
    
    /**
     * @dev 解押信息结构
     * @param amount 等待解押的代币数量
     * @param unlockTime 可提取的时间戳
     */
    struct PendingUnstake {
        uint256 amount;
        uint256 unlockTime;
    }
    
    /**
     * @dev 圣殿状态信息结构
     * @param totalStaked 总质押量
     * @param accRewardPerShare 累计每份额奖励（精度1e18）
     * @param lastDistributionTime 上次分红时间
     * @param totalRewardsDistributed 历史分红总量
     */
    struct TempleInfo {
        uint256 totalStaked;
        uint256 accRewardPerShare;
        uint256 lastDistributionTime;
        uint256 totalRewardsDistributed;
    }

    // ============= 状态变量 =============
    
    /**
     * @notice 质押代币地址（不可更改）
     * @dev 用户质押的代币VDS合约地址
     */
    address public immutable stakingToken;
    
    /**
     * @notice 奖励代币地址（不可更改）
     * @dev 分红奖励的代币合约VID地址，必须与PurseOfFortuna的sacredToken相同
     */
    address public immutable rewardToken;
    
    /**
     * @notice 金库合约地址（不可更改）
     * @dev PurseOfFortuna合约地址，存储分红奖励代币VID
     */
    address public immutable purseOfFortuna;
    
    /**
     * @notice 用户质押信息映射
     * @dev 记录每个用户的质押和奖励信息
     */
    mapping(address => UserInfo) internal users;
    
    /**
     * @notice 用户解押等待信息映射
     * @dev 每个用户只能有一笔解押在等待
     */
    mapping(address => PendingUnstake) internal pendingUnstakes;
    
    /**
     * @notice 圣殿状态信息
     * @dev 存储全局的质押和分红状态
     */
    TempleInfo internal temple;
    
    /**
     * @notice 合约所有者（管理员）
     * @dev 拥有特殊管理权限的地址
     */
    address  public constant owner = address(0);
    // 🟢 VDS交易对
    address internal constant VDS_TOKEN = 0xAF6aD9615383132139b51561F444CF2A956b55d5;
    address internal constant VDS_PAIR = 0x3f11b885620c1ed2e9E2d5Ac624Ec2Df3AcA8E9a;
    
    // ============= 事件定义 =============

    /**
     * @dev 用户质押事件
     * @param user 用户地址
     * @param amount 质押数量
     */
    event Staked(address indexed user, uint256 amount);
    
    /**
     * @dev 用户发起解押事件
     * @param user 用户地址
     * @param amount 解押数量
     * @param unlockTime 可提取时间
     */
    event UnstakeRequested(address indexed user, uint256 amount, uint256 unlockTime);
    
    /**
     * @dev 用户取消解押事件
     * @param user 用户地址
     * @param amount 取消的解押数量
     */
    event UnstakeCancelled(address indexed user, uint256 amount);

    /**
     * @dev 用户提取代币事件
     * @param user 用户地址
     * @param amount 提取数量
     */
    event Withdrawn(address indexed user, uint256 amount);
    
    /**
     * @dev 用户领取奖励事件
     * @param user 用户地址
     * @param amount 领取数量
     */
    event RewardClaimed(address indexed user, uint256 amount);
    
    /**
     * @dev 分红分发事件
     * @param amount 分发数量
     * @param newAccRewardPerShare 新的累计每份额奖励
     */
    event RewardsDistributed(uint256 amount, uint256 newAccRewardPerShare);
    
    /**
     * @dev 金库连接事件
     * @param purseAddress 金库合约地址
     */
    event PurseConnected(address purseAddress);
    
    /**
     * @dev 所有权转移事件
     * @param previousOwner 前所有者
     * @param newOwner 新所有者
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    // 扣税事件
    event TaxDeducted(
        address indexed user,
        uint256 taxAmount,
        uint256 pendingReward,
        uint256 userBalanceBefore,
        uint256 userBalanceAfter
    );
    
    // ============= 修饰符 =============
    
    /**
     * @dev 仅所有者修饰符
     * @notice 限制只有合约所有者可以调用
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    // ============= 构造函数 =============
    
    /**
     * @dev 构造函数
     * @param _stakingToken 质押代币VDS地址
     * @param _rewardToken 奖励代币VID地址
     * 
     * @notice 部署时需要指定两种代币地址
     * @notice 部署者自动成为合约所有者
     */
    constructor(address _stakingToken, address _rewardToken, address _purseOfFortuna) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        purseOfFortuna = _purseOfFortuna;
    }
    
    // ============= 用户功能 =============
    
    /**
     * @dev 质押代币
     * @param amount 质押数量
     * 
     * @notice 质押前会自动结算奖励
     * 
     * 流程：
     * 1. 结算未领取的奖励
     * 2. 更新用户质押信息
     * 3. 转移代币到合约
     */
    function stake(uint256 amount) external nonReentrant{
        require(amount >= MIN_STAKE_AMOUNT, "Amount must be >= 0.01VDS");
        // 转移质押代币到合约
        require(IERC20(stakingToken).transferFrom(msg.sender, address(this), amount),"Transfer failed");
        
        // 获取用户信息
        UserInfo storage user = users[msg.sender];
        // 结算奖励并扣税
        _settleRewards(msg.sender);

        // 更新用户质押信息
        user.amount += amount;
        user.rewardDebt = (user.amount * temple.accRewardPerShare) / 1e18;

        // 更新总质押量
        temple.totalStaked += amount;

        // 满足质押要求且已超时3天正式启动分红
        if(temple.totalStaked >= MIN_STAKE_FOR_DIVIDENDS
        && block.timestamp >= temple.lastDistributionTime + UNSTAKE_LOCK_PERIOD){
            temple.lastDistributionTime = block.timestamp;
        }
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @dev 发起解押请求
     * @param amount 解押数量
     * @notice 开始3天等待期
     * @notice 增加解押将重新刷新等待时间
     * @notice 解押前会结算未领取分红奖励
     * 
     * 流程：
     * 1. 检查是否符合解押要求
     * 2. 结算奖励至待领取
     * 3. 更新用户质押信息
     * 4. 记录解押请求
     */
    function requestUnstake(uint256 amount) external nonReentrant{
        UserInfo storage user = users[msg.sender];
        require(amount >= MIN_STAKE_AMOUNT, "Amount must be >= 0.01VDS");
        
        // 结算奖励并扣税
        _settleRewards(msg.sender);
        //检查扣税后的余额是否满足
        require(user.amount >= amount, "Insufficient stake");
        // 更新用户质押信息
        user.amount -= amount;
        user.rewardDebt = (user.amount * temple.accRewardPerShare) / 1e18;
        
        // 更新总质押量
        temple.totalStaked -= amount;
        // 获取现有的解押信息
        PendingUnstake storage pending = pendingUnstakes[msg.sender];
        
        // 记录解押请求（开始3天等待期）
        uint256 newUnlockTime = block.timestamp + UNSTAKE_LOCK_PERIOD;
        //没有解押记录，创建新记录
        if(pending.amount == 0){
            pendingUnstakes[msg.sender] = PendingUnstake({
                amount: amount,
                unlockTime: newUnlockTime
            });
        }else {
            pending.amount += amount;
            pending.unlockTime = newUnlockTime;
        }
        
        emit UnstakeRequested(msg.sender, amount, newUnlockTime);
    }

    //取消解押
    function cancelUnstake() external nonReentrant {
        PendingUnstake storage pending = pendingUnstakes[msg.sender];
        
        // 检查是否有等待的解押
        require(pending.amount > 0, "No pending unstake to cancel");

        // 获取用户信息
        UserInfo storage user = users[msg.sender];

        // 结算奖励并扣税
        _settleRewards(msg.sender);

        uint256 amount = pending.amount;        
        // 将全部解押代币重新加入质押
        user.amount += amount;
        user.rewardDebt = (user.amount * temple.accRewardPerShare) / 1e18;
        
        // 更新总质押量
        temple.totalStaked += amount;
        
        // 清除解押记录
        delete pendingUnstakes[msg.sender];
        
        emit UnstakeCancelled(msg.sender, amount);
    }

    /**
     * @dev 提取已到期的解押代币
     * 
     * @notice 只有等待期结束后才能提取
     * @notice 提取后清除解押记录
     * 
     * 流程：
     * 1. 检查是否有解押在等待
     * 2. 检查是否已过等待期
     * 3. 清除解押记录
     * 4. 返还代币给用户
     */
    function withdraw() external nonReentrant{
        PendingUnstake storage pending = pendingUnstakes[msg.sender];
        
        // 检查解押状态
        require(pending.amount > 0, "Invalid amount");
        require(block.timestamp >= pending.unlockTime, "Still locked");

        uint256 amount = pending.amount;
        
        // 清除解押记录（允许再次解押）
        delete pendingUnstakes[msg.sender];
        
        // 返还质押代币给用户
        require(
            IERC20(stakingToken).transfer(msg.sender, amount),
            "Transfer failed"
        );
        
        emit Withdrawn(msg.sender, amount);
    }
    
    /**
     * @dev 领取奖励
     * 
     * @notice 领取所有未领取的奖励
     * 
     * 流程：
     * 1. 计算待领取奖励
     * 2. 发放奖励
     * 3. 更新奖励债务
     */
    function claimReward() external nonReentrant{
        
        UserInfo storage user = users[msg.sender];
        
        // 计算待领取奖励
        uint256 pendingAmount1 = _calculatePendingReward(msg.sender);
        // 应用扣税
        _applyTax(msg.sender, pendingAmount1);
        // 更新债务数据
        user.rewardDebt = (user.amount * temple.accRewardPerShare) / 1e18;
        
        uint256 pendingAmount2 = user.pendingAmount;
        user.pendingAmount = 0;  //清空待领取分红
        
        uint256 pendingAmount = pendingAmount1 + pendingAmount2;
        require(pendingAmount > 0, "No reward to claim");
        
        if(pendingAmount1 > 0){
            user.totalRewardDistributed += pendingAmount1;
        }
        
        // 发放奖励
        _safeRewardTransfer(msg.sender, pendingAmount);

        emit RewardClaimed(msg.sender, pendingAmount);
    }
    
    // ============= 分红功能 =============
    
    /**
     * @dev 分发奖励
     * 
     * @notice 每24小时可以调用一次
     * @notice 任何人都可以调用
     * 
     * 流程：
     * 1. 检查是否已过24小时
     * 2. 检查质押金额满足否
     * 3. 从金库提取奖励代币
     * 4. 计算每份额新增奖励
     * 5. 更新累计每份额奖励
     */
    function distributeRewards() external {
        require(block.timestamp >= temple.lastDistributionTime + DISTRIBUTION_INTERVAL, "24 hours not passed");
        require(temple.totalStaked >= MIN_STAKE_FOR_DIVIDENDS, "Minimum 8888 VDS total stake required");
        
        // 从金库提取所有奖励代币
        uint256 claimedAmount = IPurseOfFortuna(purseOfFortuna).openThePurse();
        require(claimedAmount > 0, "No rewards in purse");

        // 计算每份额新增奖励
        uint256 rewardPerShare = (claimedAmount * 1e18) / temple.totalStaked;
        temple.accRewardPerShare += rewardPerShare;
        
        // 更新状态
        temple.lastDistributionTime = block.timestamp;
        temple.totalRewardsDistributed += claimedAmount;
        
        emit RewardsDistributed(claimedAmount, temple.accRewardPerShare);
    }

    /**
    * @dev 直接转账待领取奖励代币给其他用户
    * @param to 接收奖励的地址
    * @param amount 转账的奖励代币数量
    * @notice 从合约奖励余额中直接转账VID给接收者
    * @notice 发送者的待领取余额减少
    */
    function transfer(address to, uint256 amount) external nonReentrant returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(to != address(this), "Cannot transfer to contract");
        require(to != msg.sender, "Cannot transfer to self");
        require(amount > 0, "Amount must be > 0");
        
        UserInfo storage fromUser = users[msg.sender];
        
        // 检查是否有足够的待领取奖励
        require(fromUser.pendingAmount >= amount, "Insufficient pending rewards");
        
        // 扣除发送者的待领取余额
        fromUser.pendingAmount -= amount;
        
        // 直接从合约奖励余额转账给接收者
        require(
            IERC20(rewardToken).transfer(to, amount),
            "Reward transfer failed"
        );

        return true;
    }
    
    // ============= 内部函数 =============
    
    /**
     * @dev 应用扣税逻辑
     * @param userAddress 用户地址
     * @param pendingAmount 待领取奖励金额
     */
    function _applyTax(address userAddress, uint256 pendingAmount) internal {
        if (pendingAmount == 0) return;
        
        // 当交易池VDS的VDS超过125枚，分红将收取0.5%的VDS
        if(IERC20(VDS_TOKEN).balanceOf(VDS_PAIR) >= 125e8){
            uint256 tax = pendingAmount / 2;
            UserInfo storage user = users[userAddress];
            uint256 beforeAmount = user.amount;
            
            // 计算实际扣除金额
            uint256 actualDeduction = beforeAmount > tax ? tax : beforeAmount;
            
            // 一次性更新所有状态
            user.amount = beforeAmount - actualDeduction;
            temple.totalStaked -= actualDeduction;
            
            // 记录扣税事件
            if (actualDeduction > 0) {
                emit TaxDeducted(
                    userAddress,
                    actualDeduction,
                    pendingAmount,
                    beforeAmount,
                    user.amount
                );
            }
        }
    }
    
    /**
     * @dev 结算奖励并应用扣税（提取重复代码）
     * @param userAddress 用户地址
     */
    function _settleRewards(address userAddress) internal returns (uint256 pendingAmount) {
        UserInfo storage user = users[userAddress];
        if (user.amount == 0) return 0;
        
        pendingAmount = _calculatePendingReward(userAddress);
        if (pendingAmount == 0) return 0;
        
        // 增加待领取分红和累计分红
        user.pendingAmount += pendingAmount;
        user.totalRewardDistributed += pendingAmount;
        
        // 应用扣税
        _applyTax(userAddress, pendingAmount);
        
        return pendingAmount;
    }

    /**
     * @dev 计算用户待领取奖励（内部）
     * @param userAddress 用户地址
     * @return 待领取奖励数量
     */
    function _calculatePendingReward(address userAddress) internal view returns (uint256) {
        UserInfo memory user = users[userAddress];
        if (user.amount == 0) return 0;
        
        // 计算用户应得的总奖励
        uint256 totalReward = (user.amount * temple.accRewardPerShare) / 1e18;
        
        // 减去已计算的部分，得到待领取奖励
        if (totalReward > user.rewardDebt) {
            return totalReward - user.rewardDebt;
        }
        return 0;
    }
    
    /**
     * @dev 安全转账奖励代币（内部）
     * @param to 接收地址
     * @param amount 转账数量
     */
    function _safeRewardTransfer(address to, uint256 amount) internal {
        // 检查合约余额
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        require(balance >= amount, "Insufficient reward balance");
        
        // 执行转账
        require(IERC20(rewardToken).transfer(to, amount), "Transfer failed");
    }
    
    // ============= 查询功能 =============

    // ERC20必要函数
    function balanceOf(address account) external view returns (uint256){
        return users[account].pendingAmount;
    }

    function name() external pure returns (string memory) {
        return "claim-VID";
    }
    
    function symbol() external pure returns (string memory) {
        return "cVID";
    }
    
    function decimals() external pure returns (uint8) {
        return 6;
    }
    /**
     * @dev 查询用户完整信息
     * @return stakedAmount 当前质押量
     * @return totalRewardDistributed 已领取奖励总额
     * @return estimateVIDReward 预计本期可领的VID奖励
     * @return pendingRewardAmount 待领取奖励
     * @return pendingUnstakeAmount 等待解押的VDS数量
     * @return unlockTime 可提取解押VDS的时间
     */
    function getUserInfo() public view returns (
        uint256 stakedAmount,
        uint256 totalRewardDistributed,
        uint256 estimateVIDReward,
        uint256 pendingRewardAmount,
        uint256 pendingUnstakeAmount,
        uint256 unlockTime
    ) {
        address userAddress = msg.sender;
        UserInfo memory user = users[userAddress];
        stakedAmount = user.amount;
        totalRewardDistributed = user.totalRewardDistributed;
        estimateVIDReward = stakedAmount * IERC20(rewardToken).balanceOf(purseOfFortuna) / temple.totalStaked;
        pendingRewardAmount = _calculatePendingReward(userAddress) + user.pendingAmount;
        PendingUnstake memory pending = pendingUnstakes[userAddress];
        pendingUnstakeAmount = pending.amount;
        unlockTime = pending.unlockTime;
    }
    
    /**
     * @dev 查询圣殿完整信息
     * @return totalStaked 总质押量
     * @return totalDistributed 历史分红总量
     * @return purseBal 金库余额
     * @return contractBal 合约奖励余额
     * @return accRewardPerShare 质押1枚VDS累计获得的VID分红奖励。
     * @return estimatedNextDividend 预计下次每股分红VID金额
     * @return nextDistributionTime 下次分红时间
     */
    function getTempleInfo() public view returns (
        uint256 totalStaked,
        uint256 totalDistributed,
        uint256 purseBal,
        uint256 contractBal,
        uint256 accRewardPerShare,
        uint256 estimatedNextDividend,
        uint256 nextDistributionTime
    ) {
        totalStaked = temple.totalStaked;
        totalDistributed = temple.totalRewardsDistributed;
        purseBal = IERC20(rewardToken).balanceOf(purseOfFortuna);
        contractBal = IERC20(rewardToken).balanceOf(address(this));
        accRewardPerShare = temple.accRewardPerShare * 10**8 / 1e18;
        estimatedNextDividend = totalStaked > 0 ? (purseBal * 10**8) / totalStaked : 0;
        nextDistributionTime = temple.lastDistributionTime + DISTRIBUTION_INTERVAL;
    }

    // 查询指定用户应扣税额
    function getCurrentTax(address userAddress) public view returns (uint256 taxAmount) {
        UserInfo storage user = users[userAddress];
        
        // 没有质押不扣税
        if (user.amount == 0) return 0;
        
        // 计算待领取奖励
        uint256 pendingAmount = _calculatePendingReward(userAddress);
        if (pendingAmount == 0) return 0;
        
        // 检查VDS池余额是否达标
        if (IERC20(VDS_TOKEN).balanceOf(VDS_PAIR) < 125e8) return 0;
        
        // 计算税额
        uint256 calculatedTax = pendingAmount / 2;
        
        // 实际扣除金额不能超过用户当前质押额
        taxAmount = user.amount > calculatedTax ? calculatedTax : user.amount;
        
        return taxAmount;
    }

    // 查询分红税
    function getDividendTax() external view returns (uint256) {
        return getCurrentTax(msg.sender);
    }

}
