// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * 🔱 VDS Trinity Protocol 🔱
 * 🌟 三位一体流动性引擎 · 三角稳定价值体系 🌟
 * 
 * 核心理念：USDT · VID · VDS 三位一体协同
 * 功能矩阵：
 * 1. 🔵 USDT注入 → VID购买 + 流动性添加
 * 2. 🟣 VID桥梁 → 价值转移 + 池子平衡
 * 3. 🟢 VDS股权 → 用户奖励 + 生态赋能
 */

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function mint(address to) external returns (uint256 liquidity);
    function totalSupply() external view returns (uint256);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IPancakeRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    // 🟢 新增：流动性功能
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
}

import "./ReentrancyGuard.sol";

contract VDSTrinityProtocol is ReentrancyGuard{
    // ============ 🔱 三位一体核心地址 ============
    address internal constant VID = 0x65b8F22EF3F2fF7072744Fc4dC919E8e6dbE5E6A;               // 🟣 价值桥梁
    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;              // 🔵 稳定入口
    address internal constant VDS = 0xA92BD5D04121a6D02CC687129963dB9C2665cd05;               // 🟢 股权代币
    address internal constant LP_PAIR = 0xf3813595539Ab2E697f0d06e591C94A3eBAB0dF9;           // 🔵🟣 USDT-VID交易对
    address internal constant VDS_VID_PAIR = 0x92Ee2c51328b8a330681763d86685E86aD441ded;      // 🟣🟢 VDS-VID交易对
    address internal constant DIVIDEND_RESERVE = 0xe428dcd60d1755Ca19f156C14E4bfaeaf2DA90D3;  // 🏦 分红储备合约
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;                // ⚰️ 黑洞地址
    // ============ 📍 路由合约地址 ============
    address internal constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    
    // ============ ⚙️ 存款规则 ============
    uint256 internal constant MIN_DEPOSIT = 1 * 10**18;                 // 最低 1 USDT
    uint256 internal constant MAX_DEPOSIT = 10_000 * 10**18;            // 最高 10,000 USDT
    uint256 internal constant SLIPPAGE = 10;                            // 0.1% 滑点保护
    uint256 internal constant SLIPPAGE_DENOMINATOR = 10000;
    
    // ============ 🔄 资金分配比例 ============
    uint256 internal constant BUY_RATIO = 9000;                        // 90% 用于购买VID
    uint256 internal constant RATIO_DENOMINATOR = 10000;
    
    // ============ ⚖️ VDS/VID 平衡参数 ============
    uint256 internal constant MAX_REBALANCE_PERCENT = 100;             // 单次最多调整池子1%
    uint256 internal constant REBALANCE_COOLDOWN = 1 hours;            // 1小时冷却
    
    // ============ ⏳ 时间参数 ============
    uint256 internal constant CLAIM_DELAY = 10 minutes;                // 领取VDS等待时间
    
    // ============ 📊 状态变量 ============
    address internal owner;                      // 👑 合约所有者
    uint256 internal totalUSDTDeposited;         // 💰 累计存入USDT
    uint256 internal netVDSOutflow;              // 💰 净流出VDS总量
    uint256 internal lastRebalanceTime;          // ⏰ 最后平衡时间
    
    // ============ 👤 用户数据结构 ============
    struct UserInfo {
        uint256 totalDeposited;        // 💳 累计存入USDT
        uint256 totalVDSClaimed;       // 🎁 累计领取VDS
        uint256 pendingVDS;            // ⏳ 待领取VDS
        uint256 depositTime;           // 🕐 最近存入时间
    }
    
    mapping(address => UserInfo) internal userInfo;
    
    // ============ 📡 事件系统 ============
    event Deposit(
        address indexed user,
        uint256 usdtAmount,
        uint256 vidBought,
        uint256 treasuryVID,
        uint256 contractVID,
        uint256 lpBurned,
        uint256 vdsPending
    );
    event VIDPurchased(
        uint256 usdtAmount,
        uint256 vidReceived,
        uint256 treasuryShare,
        uint256 contractShare
    );
    event LiquidityAdded(
        uint256 usdtAmount,
        uint256 vidAmount,
        uint256 lpBurned
    );
    event ClaimVDS(
        address indexed user,
        uint256 vdsAmount,
        uint256 claimTime
    );
    event ForfeitVDS(
        address indexed user,
        uint256 forfeitedAmount
    );
    event VDSBalanceAdjusted(
        address indexed caller,
        uint256 vidUsed,
        uint256 vdsReceived,
        uint256 newVDSBalance,
        uint256 nextAvailableTime
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event TrinityStatus(
        uint256 usdtDepositedTotal,
        uint256 contractVIDBalance,
        uint256 contractVDSBalance,
        uint256 lastRebalance
    );
    
    // ============ 🔒 修饰符 ============
    modifier onlyOwner() {
        require(msg.sender == owner, "Trinity: Not owner");
        _;
    }
    
    // ============ 🏗️ 构造函数 ============
    constructor() {
        // ✅ 一次性授权最大额度，避免后续重复授权
        IERC20(VID).approve(PANCAKE_ROUTER, type(uint256).max);
        IERC20(USDT).approve(PANCAKE_ROUTER, type(uint256).max);
        owner = msg.sender;
        lastRebalanceTime = block.timestamp; // 初始化平衡时间
    }
    
    // ============ 🔵 核心存款函数 ============
    function deposit(uint256 usdtAmount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(usdtAmount >= MIN_DEPOSIT, "Trinity: Below minimum");
        require(usdtAmount <= MAX_DEPOSIT, "Trinity: Exceeds maximum");
        
        // 💳 接收用户USDT
        require(IERC20(USDT).transferFrom(msg.sender, address(this), usdtAmount), 
                "Trinity: USDT transfer failed");
        
        // 📊 分配比例
        uint256 usdtForBuy = usdtAmount * BUY_RATIO / RATIO_DENOMINATOR;
        uint256 usdtForLiquidity = usdtAmount - usdtForBuy;
        
        // 🌊 先添加流动性（稳定价格）
        uint256 lpBurned = 0;
        if (usdtForLiquidity > 0) {
            (uint256 vidReserve, uint256 usdtReserve) = _getUSDTVIDReserves();
            require(usdtReserve > 0, "Trinity: No USDT in pool");
            
            uint256 vidForLiquidity = usdtForLiquidity * vidReserve / usdtReserve;
            
            require(IERC20(VID).balanceOf(address(this)) >= vidForLiquidity, 
                    "Trinity: Insufficient VID for liquidity");
            require(IERC20(USDT).balanceOf(address(this)) >= usdtForLiquidity,
                    "Trinity: Insufficient USDT for liquidity");
            
            lpBurned = _addLiquidityDirect(vidForLiquidity, usdtForLiquidity);
        }
        
        // 🟣 后购买VID
        uint256 vidBought = 0;
        uint256 treasuryVID = 0;
        uint256 contractVID = 0;
        
        if (usdtForBuy > 0) {
           
            vidBought = _swapUSDTForVIDDirect(usdtForBuy);

            uint256 treasuryPercent = _calculateTreasuryPercent();

            treasuryVID = vidBought * treasuryPercent / RATIO_DENOMINATOR;
            contractVID = vidBought - treasuryVID;
            
            if (treasuryVID > 0) {
                require(IERC20(VID).transfer(DIVIDEND_RESERVE, treasuryVID), 
                        "Trinity: Treasury transfer failed");
            }
            
            emit VIDPurchased(usdtForBuy, vidBought, treasuryVID, contractVID);
        }

        // 🎁 计算VDS股权奖励
        (uint256 finalVIDReserve, uint256 finalUSDTReserve) = _getUSDTVIDReserves();
        require(finalUSDTReserve > 0, "Trinity: Cannot calculate reward");
        
        // 计算全部USDT能买到的VID数量（按添加流动性后的价格）
        uint256 totalVIDForUSDT = usdtAmount * finalVIDReserve / finalUSDTReserve;
        
        // VDS奖励计算：min(全部USDT能买到的VID, USDT换算的VDS)
        uint256 vdsForUSDT = usdtAmount / 1e12;
        uint256 vdsReward = _min(totalVIDForUSDT, vdsForUSDT);

        // 📝 更新用户状态
        user.totalDeposited += usdtAmount;
        user.pendingVDS += vdsReward;
        user.depositTime = block.timestamp;
        
        // 📈 更新全局状态
        totalUSDTDeposited += usdtAmount;
        netVDSOutflow += vdsReward;
        require(IERC20(VDS).balanceOf(address(this)) >= user.pendingVDS, "Insufficient VDS");
        
        // 📡 发射存款事件
        emit Deposit(msg.sender, usdtAmount, vidBought, treasuryVID, contractVID, lpBurned, vdsReward);
        
        // 🎯 更新系统状态
        emit TrinityStatus(
            totalUSDTDeposited,
            IERC20(VID).balanceOf(address(this)),
            IERC20(VDS).balanceOf(address(this)),
            lastRebalanceTime
        );
    }
    
    // ============ 🟢 领取VDS函数 ============
    function claimVDS() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        
        require(user.pendingVDS > 0, "Trinity: No pending VDS");
        require(block.timestamp >= user.depositTime + CLAIM_DELAY, 
                "Trinity: Claim not available yet");
        
        uint256 vdsToClaim = user.pendingVDS;
        require(IERC20(VDS).balanceOf(address(this)) >= vdsToClaim, 
                "Trinity: Insufficient VDS");
        
        user.totalVDSClaimed += vdsToClaim;
        user.pendingVDS = 0;
        
        require(IERC20(VDS).transfer(msg.sender, vdsToClaim), 
                "Trinity: VDS transfer failed");
        
        emit ClaimVDS(msg.sender, vdsToClaim, block.timestamp);
    }
    
    // ============ ⚖️ VDS/VID平衡函数 ============
    function maintainVDSBalance() external nonReentrant returns (uint256 vidUsed, uint256 vdsReceived) {
        require(block.timestamp >= lastRebalanceTime + REBALANCE_COOLDOWN, 
                "Trinity: Rebalance in cooldown");

        vidUsed = _calculateVidNeeded();
        
        require(vidUsed > 0, "Trinity: No VID needed");
        
        uint256 contractVIDBalance = IERC20(VID).balanceOf(address(this));
        require(contractVIDBalance >= vidUsed, "Trinity: Insufficient VID in contract");
        
        vdsReceived = _swapVIDForVDS(vidUsed);
        require(vdsReceived > 0, "No VDS received");
        require(netVDSOutflow >= vdsReceived, "Insufficient VDS in netVDSOutflow");
        
        lastRebalanceTime = block.timestamp;
        netVDSOutflow -= vdsReceived;

        emit VDSBalanceAdjusted(
            msg.sender, 
            vidUsed, 
            vdsReceived, 
            IERC20(VDS).balanceOf(address(this)),
            lastRebalanceTime + REBALANCE_COOLDOWN
        );
        
        return (vidUsed, vdsReceived);
    }
    
    // ============ 🔄 直接交换函数 ============
    //USDT兑换VID
    function _swapUSDTForVIDDirect(uint256 usdtAmount) internal returns (uint256 vidReceived) {
        require(usdtAmount > 0, "Trinity: Zero USDT amount");

        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = VID;
        
        uint256[] memory amounts = IPancakeRouter(PANCAKE_ROUTER).getAmountsOut(usdtAmount, path);
        require(amounts.length == 2, "Trinity: Invalid amounts");
        
        uint256 vidExpected = amounts[1];
        require(vidExpected > 0, "Trinity: Zero output");
        
        // 🛡️ 滑点保护
        uint256 minVIDOut = vidExpected * (SLIPPAGE_DENOMINATOR - SLIPPAGE) / SLIPPAGE_DENOMINATOR;
        
        uint256 vidBefore = IERC20(VID).balanceOf(address(this));
        
        // 🥞 执行交换
        IPancakeRouter(PANCAKE_ROUTER).swapExactTokensForTokens(
            usdtAmount,
            minVIDOut,
            path,
            address(this),
            block.timestamp + 300
        );
        
        uint256 vidAfter = IERC20(VID).balanceOf(address(this));
        vidReceived = vidAfter - vidBefore;
        
        require(vidReceived >= minVIDOut, "Trinity: High slippage");
        
        return vidReceived;
    }
    //VID兑换VDS
    function _swapVIDForVDS(uint256 vidAmount) internal returns (uint256 vdsReceived) {
        require(vidAmount > 0, "Trinity: Zero VID amount");

        address[] memory path = new address[](2);
        path[0] = VID;
        path[1] = VDS;
        
        uint256[] memory amounts = IPancakeRouter(PANCAKE_ROUTER).getAmountsOut(vidAmount, path);
        require(amounts.length == 2, "Trinity: Invalid amounts");
        
        uint256 vdsExpected = amounts[1];
        require(vdsExpected > 0, "Trinity: Zero output");
        
        // 🛡️ 滑点保护
        uint256 minVDSOut = vdsExpected * (SLIPPAGE_DENOMINATOR - SLIPPAGE) / SLIPPAGE_DENOMINATOR;
        
        uint256 vdsBefore = IERC20(VDS).balanceOf(address(this));
        
        IPancakeRouter(PANCAKE_ROUTER).swapExactTokensForTokens(
            vidAmount,
            minVDSOut,
            path,
            address(this),
            block.timestamp + 300 // 5分钟超时
        );
        
        uint256 vdsAfter = IERC20(VDS).balanceOf(address(this));
        vdsReceived = vdsAfter - vdsBefore;
        
        require(vdsReceived >= minVDSOut, "Trinity: High slippage");
        
        return vdsReceived;
    }
    
    // ============ 🌊 添加流动性 ============
    //添加USDT/VID的LP
    function _addLiquidityDirect(uint256 vidAmount, uint256 usdtAmount) internal returns (uint256 liquidity) {
        require(vidAmount > 0 && usdtAmount > 0, "Trinity: Zero amount");

        // 计算最小接受量（考虑滑点）
        uint256 amountVIDMin = vidAmount * (SLIPPAGE_DENOMINATOR - SLIPPAGE) / SLIPPAGE_DENOMINATOR;
        uint256 amountUSDTMin = usdtAmount * (SLIPPAGE_DENOMINATOR - SLIPPAGE) / SLIPPAGE_DENOMINATOR;
        
        // 🥞 通过 Router 添加流动性
        (uint256 usedVID, uint256 usedUSDT, uint256 lpReceived) = 
            IPancakeRouter(PANCAKE_ROUTER).addLiquidity(
                VID,
                USDT,
                vidAmount,          // 期望的 VID 数量
                usdtAmount,         // 期望的 USDT 数量
                amountVIDMin,       // 最少接受的 VID
                amountUSDTMin,      // 最少接受的 USDT
                DEAD,               // LP 发送到黑洞地址（真正销毁）
                block.timestamp + 300
            );
        // 💡 记录实际使用的数量
        emit LiquidityAdded(usedUSDT, usedVID, lpReceived);
        return lpReceived;
    }
    
    // ============ 📊 查询函数 ============

    // 1. 获取三位一体协议整体状态
    function getTrinityStatus() external view returns (
        uint256 totalDeposited,          // 📈 累计存入的USDT总量
        uint256 contractVIDBalance,      // 🟣 合约当前持有的VID余额
        uint256 contractVDSBalance,      // 🟢 合约当前持有的VDS余额
        uint256 netVDSOutflowed          // ✅ VDS净注出动态平衡总量
    ) {
        
        return (
            totalUSDTDeposited,                           // 全局存款总额
            IERC20(VID).balanceOf(address(this)),         // 实时VID余额
            IERC20(VDS).balanceOf(address(this)),         // 实时VDS余额
            netVDSOutflow                                 // VDS净流出总量
        );
    }

    // 2. 获取VDS-VID交易对池子状态
    function getVDSVIDPoolStatus() external view returns (
        uint256 currentRatio,     // ⚖️ 当前VID/VDS比率（放大100倍平衡精度）
        uint256 nextRebalance,    // 🔄 下次平衡所需VID金额
        uint256 nextReTimer       // ⏰ 下次平衡时间
    ) {
        uint256 vdsReserve;
        uint256 vidReserve;
        (vdsReserve, vidReserve) = _getVDSVIDReserves();  // 获取实时储备

        currentRatio = vidReserve * 100 / vdsReserve;           // 计算平衡精度后的值
        nextRebalance = _calculateVidNeeded();                  // 获取本次VID注入金额
        nextReTimer = lastRebalanceTime + REBALANCE_COOLDOWN;   // 下次注入VID平衡时间
        
        return (currentRatio, nextRebalance, nextReTimer);
    }

    // 3. 获取单个用户信息
    function getUserInfo() external view returns (
        uint256 totalDeposited,   // 💰 该用户累计存入的USDT总量
        uint256 totalClaimed,     // 🎁 该用户累计领取的VDS总量
        uint256 pendingVDS,       // ⏳ 该用户待领取的VDS数量
        uint256 depositTime       // 🕐 该用户最近一次存款时间
    ) {
        address user = msg.sender;
        UserInfo storage info = userInfo[user];
        return (
            info.totalDeposited,      // 用户存款总额
            info.totalVDSClaimed,     // 已领取总奖励
            info.pendingVDS,          // 待领取总奖励
            info.depositTime          // 上次存款时间
        );
    }
    
    // ============ 🛠️ 内部辅助函数 ============
    //获取USDT/VID交易池数据
    function _getUSDTVIDReserves() internal view returns (uint256 vidReserve, uint256 usdtReserve) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(LP_PAIR).getReserves();
        address token0 = IUniswapV2Pair(LP_PAIR).token0();
        
        if (token0 == VID) {
            vidReserve = uint256(reserve0);
            usdtReserve = uint256(reserve1);
        } else {
            vidReserve = uint256(reserve1);
            usdtReserve = uint256(reserve0);
        }
    }
    //获取VDS/VID交易池数据
    function _getVDSVIDReserves() internal view returns (uint256 vdsReserve, uint256 vidReserve) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(VDS_VID_PAIR).getReserves();
        address token0 = IUniswapV2Pair(VDS_VID_PAIR).token0();
        
        if (token0 == VID) {
            vidReserve = uint256(reserve0);
            vdsReserve = uint256(reserve1);
        } else {
            vidReserve = uint256(reserve1);
            vdsReserve = uint256(reserve0);
        }
    }
    //计算VID注入分红合约比例
    function _calculateTreasuryPercent() internal view returns (uint256) {
        if (netVDSOutflow >= 7777e8) return 3333;
        if (netVDSOutflow >= 5555e8) return 5555;
        if (netVDSOutflow >= 3333e8) return 6666;
        return 7777;
    }

    // ✅ 计算平衡最低需要的VID数量
    function _calculateVidNeeded() internal view returns (uint256) {
        (uint256 vdsInPair, uint256 vidInPair) = _getVDSVIDReserves();

        uint256 vdsRate = _calculateVDSRate();
        uint256 targetVid = vdsInPair * vdsRate / 100;  //平衡精度
        if (targetVid <= vidInPair) {
            return 0;
        }
        
        uint256 needed = targetVid - vidInPair;
        uint256 maxVidToUse = vidInPair * MAX_REBALANCE_PERCENT / 10000;

        return _min(needed, maxVidToUse);
    }
    
    //计算VDS平衡比率
    function _calculateVDSRate() internal view returns (uint256) {
        if (netVDSOutflow >= 5555e8) return 20;
        if (netVDSOutflow >= 3333e8) return 30;
        if (netVDSOutflow >= 2222e8) return 40;
        if (netVDSOutflow >= 1111e8) return 50;
        if (netVDSOutflow >= 555e8) return 60;
        if (netVDSOutflow >= 222e8) return 70;
        if (netVDSOutflow >= 111e8) return 80;
        return 90;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    // ============ 👑 管理函数 ============

    //以防万一紧急提款
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(to, amount), "Transfer failed");
    }
    //转移管理权限
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}