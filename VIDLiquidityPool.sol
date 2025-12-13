/**
 *Submitted for verification at BscScan.com on 2025-12-02
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨
//            ⚡️🦄 银河级流动性引擎 🦄⚡️
//           🚀 融合DeFi最前沿的AMM算法 🚀
//           💎 零信任 · 全自动 · 超安全 💎
// 🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨🌟✨

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function mint(address to) external returns (uint256 liquidity);
    function totalSupply() external view returns (uint256);
}

// 🔗 星际代币接口 · 赋能跨链价值传输
contract VIDLiquidityPool {
    // ============ 代币地址 ============
    address public constant VID = 0x65b8F22EF3F2fF7072744Fc4dC919E8e6dbE5E6A;
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant VDS = 0xA92BD5D04121a6D02CC687129963dB9C2665cd05;
    address public constant LP_PAIR = 0xf3813595539Ab2E697f0d06e591C94A3eBAB0dF9;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    
    // ============ 精度 ============
    uint256 public constant VID_DECIMALS = 6;
    uint256 public constant USDT_DECIMALS = 18;
    uint256 public constant VDS_DECIMALS = 8;
    
    // ============ 规则参数 ============
    uint256 public constant MIN_DEPOSIT = 1 * 10**USDT_DECIMALS;
    uint256 public constant MAX_DEPOSIT = 10_000 * 10**USDT_DECIMALS;
    uint256 public constant SLIPPAGE = 50;  // 0.5%
    uint256 public constant SLIPPAGE_DENOMINATOR = 10000;
    
    // ============ 清理阈值 ============
    uint256 public constant CLEANUP_VID_THRESHOLD = 10**4;    // 0.01 VID
    uint256 public constant CLEANUP_USDT_THRESHOLD = 10**17;  // 0.1 USDT
    
    // ============ 状态变量 ============
    address public owner;
    uint256 public totalUSDTDeposited;
    bool private _locked;
    
    // ============ 用户数据 ============
    mapping(address => uint256) public userDeposited;
    mapping(address => uint256) public userVDSReceived;
    
    // ============ 事件 ============
    event Deposit(
        address indexed user,
        uint256 usdtAmount,
        uint256 vidUsed,
        uint256 vdsReceived,
        uint256 lpBurned
    );
    event OwnerWithdraw(address indexed token, address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ReservesCleaned(uint256 excessVID, uint256 excessUSDT, uint256 lpBurned);
    
    // ============ 修饰符 ============
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }
    
    // ============ 构造函数 ============
    constructor() {
        owner = msg.sender;
    }
    
    // ============ 核心用户函数 ============
    
    /// @notice 存入 USDT，获得 VDS
    /// @param usdtAmount 存入的 USDT 数量
    function deposit(uint256 usdtAmount) external nonReentrant {
        
        // === 第一步：主动清理防御 ===
        _cleanupExcessReserves();
        
        // === 第二步：基础验证 ===
        require(usdtAmount >= MIN_DEPOSIT, "Below minimum deposit");
        require(usdtAmount <= MAX_DEPOSIT, "Exceeds maximum deposit");
        
        // === 第三步：获取实时验证的储备金 ===
        (uint256 vidReserve, uint256 usdtReserve) = _getValidatedReserves();
        require(vidReserve > 0 && usdtReserve > 0, "Empty reserves");
        
        // === 第四步：计算需要的 VID ===
        uint256 vidNeeded = usdtAmount * vidReserve / usdtReserve;
        require(vidNeeded > 0, "Invalid VID amount");
        
        // === 第五步：检查合约余额 ===
        uint256 vidBalance = IERC20(VID).balanceOf(address(this));
        require(vidBalance >= vidNeeded, "Insufficient VID in contract");
        
        // === 第六步：计算 VDS 奖励 ===
        uint256 vdsForUSDT = usdtAmount / 1e12;
        uint256 vdsToSend = _min(vidNeeded, vdsForUSDT);
        
        uint256 vdsBalance = IERC20(VDS).balanceOf(address(this));
        require(vdsBalance >= vdsToSend, "Insufficient VDS in contract");
        
        // === 第七步：计算预期 LP（滑点保护） ===
        uint256 lpTotalSupply = IUniswapV2Pair(LP_PAIR).totalSupply();
        uint256 expectedLP = _min(
            vidNeeded * lpTotalSupply / vidReserve,
            usdtAmount * lpTotalSupply / usdtReserve
        );
        uint256 minLP = expectedLP * (SLIPPAGE_DENOMINATOR - SLIPPAGE) / SLIPPAGE_DENOMINATOR;
        
        // === 第八步：接收用户 USDT ===
        require(IERC20(USDT).transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        
        // === 第九步：原子操作：转账 + mint ===
        
        // 转 VID 到 Pair
        require(IERC20(VID).transfer(LP_PAIR, vidNeeded), "VID transfer to pair failed");
        
        // 转 USDT 到 Pair
        require(IERC20(USDT).transfer(LP_PAIR, usdtAmount), "USDT transfer to pair failed");
        
        // 调用 mint，LP 直接发送到黑洞
        uint256 liquidity = IUniswapV2Pair(LP_PAIR).mint(DEAD);
        
        // === 第十步：滑点保护检查 ===
        require(liquidity >= minLP, "Slippage exceeded");
        require(liquidity > 0, "No liquidity minted");
        
        // === 第十一步：更新状态 ===
        totalUSDTDeposited += usdtAmount;
        userDeposited[msg.sender] += usdtAmount;
        userVDSReceived[msg.sender] += vdsToSend;
        
        // === 第十二步：发送 VDS 奖励 ===
        require(IERC20(VDS).transfer(msg.sender, vdsToSend), "VDS transfer failed");
        
        // === 第十三步：发射事件 ===
        emit Deposit(msg.sender, usdtAmount, vidNeeded, vdsToSend, liquidity);
    }
    
    // ============ 核心安全函数 ============
    
    /// @notice 主动清理多余的储备金（防御攻击）
    function _cleanupExcessReserves() internal {
        // 获取实时余额
        uint256 realVID = IERC20(VID).balanceOf(LP_PAIR);
        uint256 realUSDT = IERC20(USDT).balanceOf(LP_PAIR);
        
        // 获取记录中的储备金
        (uint256 storedVID, uint256 storedUSDT) = _getReserves();
        
        // 计算多余的金额
        uint256 excessVID = realVID > storedVID ? realVID - storedVID : 0;
        uint256 excessUSDT = realUSDT > storedUSDT ? realUSDT - storedUSDT : 0;
        
        // 检查是否超过清理阈值
        bool shouldClean = false;
        
        if (excessVID > 0 && excessUSDT > 0) {
            // 两种代币都有多余 - 肯定是攻击，立即清理
            shouldClean = true;
        } else if (excessVID >= CLEANUP_VID_THRESHOLD) {
            // VID 超过阈值
            shouldClean = true;
        } else if (excessUSDT >= CLEANUP_USDT_THRESHOLD) {
            // USDT 超过阈值
            shouldClean = true;
        }
        
        if (shouldClean) {
            // 执行清理：将多余资金转换为 LP 并烧毁
            uint256 lpBefore = IERC20(LP_PAIR).balanceOf(DEAD);
            IUniswapV2Pair(LP_PAIR).mint(DEAD);
            uint256 lpAfter = IERC20(LP_PAIR).balanceOf(DEAD);
            uint256 lpBurned = lpAfter - lpBefore;
            
            emit ReservesCleaned(excessVID, excessUSDT, lpBurned);
        }
    }

    function _getValidatedReserves() internal view returns (uint256 vidReserve, uint256 usdtReserve) {
        (vidReserve, usdtReserve) = _getReserves();
        require(vidReserve > 0 && usdtReserve > 0, "Empty reserves");
        // 不检查实时余额，清理函数会处理多余部分
    }
    
    /// @notice 获取 Pair 储备金（原始）
    function _getReserves() internal view returns (uint256 vidReserve, uint256 usdtReserve) {
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
    
    /// @notice 返回较小值
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    // ============ 查询函数 ============
    
    /// @notice 查询存入指定 USDT 能获得多少 VDS
    function getQuote(uint256 usdtAmount) external view returns (uint256 vidNeeded, uint256 vdsToReceive) {
        (uint256 vidReserve, uint256 usdtReserve) = _getValidatedReserves();
        if (vidReserve == 0 || usdtReserve == 0) {
            return (0, 0);
        }
        vidNeeded = usdtAmount * vidReserve / usdtReserve;

        uint256 vdsForUSDT = usdtAmount / 1e12;
        uint256 vdsFromVID = vidNeeded;

        vdsToReceive = _min(vdsFromVID, vdsForUSDT);

    }
    
    /// @notice 查询合约剩余 VID
    function getRemainingVID() external view returns (uint256) {
        return IERC20(VID).balanceOf(address(this));
    }
    
    /// @notice 查询合约剩余 VDS
    function getRemainingVDS() external view returns (uint256) {
        return IERC20(VDS).balanceOf(address(this));
    }
    
    /// @notice 查询用户累计存入的 USDT
    function getUserDeposited(address user) external view returns (uint256) {
        return userDeposited[user];
    }
    
    /// @notice 查询用户累计获得的 VDS
    function getUserVDSReceived(address user) external view returns (uint256) {
        return userVDSReceived[user];
    }
    
    /// @notice 获取当前 VID 价格（1 VID 值多少 USDT，精度1e18）
    function getVIDPrice() external view returns (uint256) {
        (uint256 vidReserve, uint256 usdtReserve) = _getValidatedReserves();
        if (vidReserve == 0 || usdtReserve == 0) {
            return 0;
        }
        
        // 转换为实际代币数量：
        uint256 usdtActual = usdtReserve / 10**USDT_DECIMALS;  // 实际USDT数量
        uint256 vidActual = vidReserve / 10**VID_DECIMALS;     // 实际VID数量
        
        // 1 VID 的价格 = (总USDT价值) / (总VID数量)
        // 返回精度1e18（1e18 = 1 USDT）
        return (usdtActual * 1e18) / vidActual;
    }

    /// @notice 获取当前 VID/USDT 价格（1 USDT 能换多少 VID）
    function getVIDPerUSDT() external view returns (uint256) {
        (uint256 vidReserve, uint256 usdtReserve) = _getValidatedReserves();
        if (usdtReserve == 0) {
            return 0;
        }
        return (10**USDT_DECIMALS) * vidReserve / usdtReserve;
    }
    
    /// @notice 检查是否需要清理（管理用）
    function checkCleanupNeeded() external view returns (bool needed, uint256 excessVID, uint256 excessUSDT) {
        uint256 realVID = IERC20(VID).balanceOf(LP_PAIR);
        uint256 realUSDT = IERC20(USDT).balanceOf(LP_PAIR);
        (uint256 storedVID, uint256 storedUSDT) = _getReserves();
        
        excessVID = realVID > storedVID ? realVID - storedVID : 0;
        excessUSDT = realUSDT > storedUSDT ? realUSDT - storedUSDT : 0;
        
        needed = (excessVID >= CLEANUP_VID_THRESHOLD) || (excessUSDT >= CLEANUP_USDT_THRESHOLD);
    }
    
    // ============ 管理函数 ============
    
    /// @notice 手动触发清理（紧急情况）
    function forceCleanup() external onlyOwner {
        _cleanupExcessReserves();
    }
    
    /// @notice 提取代币
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");
        require(IERC20(token).transfer(to, amount), "Transfer failed");
        emit OwnerWithdraw(token, to, amount);
    }
    
    /// @notice 提取全部指定代币
    function withdrawAllToken(address token, address to) external onlyOwner {
        require(to != address(0), "Invalid address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No balance");
        require(IERC20(token).transfer(to, balance - 1), "Transfer failed");
        emit OwnerWithdraw(token, to, balance);
    }
    
    /// @notice 转移所有权
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    /// @notice 紧急提取 BNB
    function withdrawBNB(address to) external onlyOwner {
        require(to != address(0), "Invalid address");
        uint256 balance = address(this).balance;
        require(balance > 0, "No BNB balance");
        (bool success, ) = to.call{value: balance}("");
        require(success, "BNB transfer failed");
    }
    
    receive() external payable {}
}