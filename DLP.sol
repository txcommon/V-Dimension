// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function mint(address to) external returns (uint256 liquidity);
    function totalSupply() external view returns (uint256);
}

/**
 * @title SafeLPInjector - 安全LP注入合约（带白名单）
 * @notice 支持单币和双币注入流动性，仅白名单地址可操作
 * @dev 所有代币从合约余额扣除，管理员需预先转账代币到合约
 */
contract SafeLPInjector {
    // ============ 核心结构 ============
    struct LPConfig {
        address pair;      // LP合约地址
        address tokenA;    // 代币A地址
        address tokenB;    // 代币B地址
        bool enabled;      // true=单币模式使用tokenA，false=单币模式使用tokenB
    }
    
    // ============ 状态变量 ============
    address public owner;
    uint256 public configCount;
    mapping(uint256 => LPConfig) public lpConfigs;
    mapping(address => bool) public whitelist;
    bool private _locked;
    bool public whitelistEnabled;
    
    // ============ 常量 ============
    uint256 private constant SLIPPAGE_DENOMINATOR = 10000;
    uint256 private constant MIN_LP_THRESHOLD = 1000;
    uint256 private constant MIN_CLEAN_THRESHOLD = 1000;
    
    // ============ 事件 ============
    event SingleTokenInjected(
        uint256 indexed configId,
        address inputToken,
        uint256 inputAmount,
        address pairToken,
        uint256 pairAmount,
        address Received,
        uint256 timestamp
    );
    
    event ConfigAdded(uint256 indexed configId, address pair, address tokenA, address tokenB, bool enabled);
    event ConfigEnabled(uint256 indexed configId, bool enabled);
    event WhitelistAdded(address indexed account);
    event WhitelistRemoved(address indexed account);
    event WhitelistEnabled(bool enabled);
    event ReservesCleaned(address indexed pair, uint256 lpBurned);
    event TokensWithdrawn(address indexed token, address indexed to, uint256 amount);
    event NativeWithdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    
    // ============ 错误信息 ============
    error InsufficientBalance(address token);
    error InvalidConfig();
    error EmptyReserves();
    error SlippageExceeded();
    error Reentrancy();
    error NotOwner();
    error NotWhitelisted();
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error SameToken();
    error TokenMismatch();
    error ApprovalFailed();
    
    // ============ 修饰符 ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    
    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }
    
    modifier validConfig(uint256 configId) {
        if (configId >= configCount) revert InvalidConfig();
        if (!lpConfigs[configId].enabled) revert InvalidConfig();
        _;
    }
    
    modifier positiveAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }
    
    modifier validAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }
    
    modifier onlyPermitted() {
        if (msg.sender == owner) {
            _;
            return;
        }
        if (whitelistEnabled && !whitelist[msg.sender]) {
            revert NotWhitelisted();
        }
        _;
    }
    
    // ============ 构造函数 ============
    constructor() {
        owner = msg.sender;
        whitelistEnabled = true;
        whitelist[owner] = true;
    }
    
    // ============ 核心函数：单币注入 ============
    function injectSingleToken(
        uint256 configId,
        uint256 amount
    ) external nonReentrant onlyPermitted validConfig(configId) positiveAmount(amount) 
    returns (uint256 lpReceived, uint256 pairedAmount) {
        LPConfig memory config = lpConfigs[configId];
        
        // 确定输入代币和配对代币
        address inputToken;
        address pairToken;
        if (config.enabled) {
            inputToken = config.tokenA;
            pairToken = config.tokenB;
        } else {
            inputToken = config.tokenB;
            pairToken = config.tokenA;
        }
        
        // 获取实时储备金
        (uint256 reserveIn, uint256 reserveOut) = _getRealTimeReserves(config.pair, inputToken, pairToken);
        if (reserveIn == 0 || reserveOut == 0) revert EmptyReserves();
        
        // 计算需要的配对代币数量
        pairedAmount = (amount * reserveOut) / reserveIn;
        if (pairedAmount == 0) revert ZeroAmount();
        
        // 检查余额
        _checkContractBalance(inputToken, amount);
        _checkContractBalance(pairToken, pairedAmount);
        
        // 计算最小LP
        uint256 totalSupply = IUniswapV2Pair(config.pair).totalSupply();
        uint256 minLP;
        if (config.enabled) {
            minLP = _calculateMinLP(amount, pairedAmount, reserveIn, reserveOut, totalSupply);
        } else {
            minLP = _calculateMinLP(pairedAmount, amount, reserveIn, reserveOut, totalSupply);
        }
        
        // 执行LP注入
        lpReceived = _executeLpInjection(config.pair, inputToken, pairToken, amount, pairedAmount, msg.sender);
        
        // 滑点保护
        if (lpReceived < minLP) revert SlippageExceeded();

        emit SingleTokenInjected(configId, inputToken, amount, pairToken, pairedAmount, msg.sender, block.timestamp);
    }
    
    // ============ 内部核心函数 ============
    function _executeLpInjection(
        address pair,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address receiver
    ) private returns (uint256 lpReceived) {
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        
        uint256 amount0;
        uint256 amount1;
        
        if (tokenA == token0 && tokenB == token1) {
            amount0 = amountA;
            amount1 = amountB;
        } else if (tokenA == token1 && tokenB == token0) {
            amount0 = amountB;
            amount1 = amountA;
        } else {
            revert TokenMismatch();
        }
        
        if (!IERC20(token0).transfer(pair, amount0)) revert TransferFailed();
        if (!IERC20(token1).transfer(pair, amount1)) revert TransferFailed();
        
        lpReceived = IUniswapV2Pair(pair).mint(receiver);
        if (lpReceived == 0) revert("No LP minted");
        
        return lpReceived;
    }
    
    function _getRealTimeReserves(
        address pair,
        address tokenA,
        address tokenB
    ) private returns (uint256 reserveA, uint256 reserveB) {
        _autoCleanReserves(pair);
        
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        
        if (token0 == tokenA) {
            reserveA = uint256(reserve0);
            reserveB = uint256(reserve1);
        } else {
            reserveA = uint256(reserve1);
            reserveB = uint256(reserve0);
        }
        
        _validateReserves(pair, tokenA, tokenB, reserveA, reserveB);
    }
    
    function _autoCleanReserves(address pair) private {
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        
        (uint112 reserve0, uint112 reserve1,) = pairContract.getReserves();
        uint256 balance0 = IERC20(pairContract.token0()).balanceOf(pair);
        uint256 balance1 = IERC20(pairContract.token1()).balanceOf(pair);
        
        uint256 excess0 = balance0 > uint256(reserve0) ? balance0 - uint256(reserve0) : 0;
        uint256 excess1 = balance1 > uint256(reserve1) ? balance1 - uint256(reserve1) : 0;
        
        if (excess0 > MIN_CLEAN_THRESHOLD || excess1 > MIN_CLEAN_THRESHOLD) {
            uint256 lpBefore = IERC20(pair).balanceOf(address(this));
            pairContract.mint(address(this));
            uint256 lpAfter = IERC20(pair).balanceOf(address(this));
            
            emit ReservesCleaned(pair, lpAfter - lpBefore);
        }
    }
    
    function _validateReserves(
        address pair,
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB
    ) private view {
        uint256 balanceA = IERC20(tokenA).balanceOf(pair);
        uint256 balanceB = IERC20(tokenB).balanceOf(pair);
        
        uint8 decimalsA = IERC20(tokenA).decimals();
        uint8 decimalsB = IERC20(tokenB).decimals();
        uint256 toleranceA = 10 * 10**(decimalsA > 6 ? decimalsA - 6 : 0);
        uint256 toleranceB = 10 * 10**(decimalsB > 6 ? decimalsB - 6 : 0);
        
        if (balanceA > reserveA + toleranceA || balanceA < reserveA - toleranceA ||
            balanceB > reserveB + toleranceB || balanceB < reserveB - toleranceB) {
            revert("Reserves manipulated");
        }
    }
    
    function _calculateMinLP(
        uint256 amountA,
        uint256 amountB,
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalSupply
    ) private pure returns (uint256 minLP) {
        if (totalSupply == 0) {
            uint256 liquidity = _sqrt(amountA * amountB);
            minLP = (liquidity * 9000) / 10000;
        } else {
            uint256 liquidityA = (amountA * totalSupply) / reserveA;
            uint256 liquidityB = (amountB * totalSupply) / reserveB;
            uint256 liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
            minLP = (liquidity * 9950) / 10000;
        }
        
        if (minLP < MIN_LP_THRESHOLD) minLP = MIN_LP_THRESHOLD;
    }
    
    function _checkContractBalance(address token, uint256 required) private view {
        if (IERC20(token).balanceOf(address(this)) < required) {
            revert InsufficientBalance(token);
        }
    }
    
    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    
    // ============ 配置管理 ============
    function addConfig(
        address pair,
        address tokenA,
        address tokenB,
        bool enabled
    ) external onlyOwner validAddress(pair) validAddress(tokenA) validAddress(tokenB) returns (uint256 configId) {
        if (tokenA == tokenB) revert SameToken();
        
        configId = configCount;
        lpConfigs[configId] = LPConfig(pair, tokenA, tokenB, enabled);
        configCount++;
        
        emit ConfigAdded(configId, pair, tokenA, tokenB, enabled);
    }
    
    function setConfigEnabled(uint256 configId, bool enabled) external onlyOwner {
        if (configId >= configCount) revert InvalidConfig();
        lpConfigs[configId].enabled = enabled;
        emit ConfigEnabled(configId, enabled);
    }
    

    
    // ============ 白名单管理 ============
    function addToWhitelist(address account) external onlyOwner validAddress(account) {
        whitelist[account] = true;
        emit WhitelistAdded(account);
    }
    
    function removeFromWhitelist(address account) external onlyOwner validAddress(account) {
        whitelist[account] = false;
        emit WhitelistRemoved(account);
    }
    
    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
        emit WhitelistEnabled(enabled);
    }

    
    function isWhitelisted(address account) external view returns (bool) {
        return whitelist[account];
    }
    
    // ============ 资金管理 ============
    function withdrawToken(address token, address to, uint256 amount) 
        external 
        onlyOwner 
        validAddress(token) 
        validAddress(to) 
        positiveAmount(amount) 
    {
        if (IERC20(token).balanceOf(address(this)) < amount) revert InsufficientBalance(token);
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        emit TokensWithdrawn(token, to, amount);
    }
    
    function withdrawNative(address to) 
        external 
        onlyOwner 
        validAddress(to) 
    {
        uint256 balance = address(this).balance;
        if (balance == 0) revert ZeroAmount();
        
        (bool success, ) = to.call{value: balance}("");
        if (!success) revert TransferFailed();
        
        emit NativeWithdrawn(to, balance);
    }
    
    function transferOwnership(address newOwner) external onlyOwner validAddress(newOwner) {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    // ============ 查询函数 ============
    function getPairTokenNeeded(uint256 configId, uint256 amount) external view returns (uint256 needed) {
        if (configId >= configCount) revert InvalidConfig();
        LPConfig memory config = lpConfigs[configId];
        
        address inputToken;
        address pairToken;
        if (config.enabled) {
            inputToken = config.tokenA;
            pairToken = config.tokenB;
        } else {
            inputToken = config.tokenB;
            pairToken = config.tokenA;
        }
        
        (uint256 reserveIn, uint256 reserveOut) = _getReservesView(config.pair, inputToken, pairToken);
        if (reserveIn == 0 || reserveOut == 0) return 0;
        
        needed = (amount * reserveOut) / reserveIn;
    }
    
    function getConfig(uint256 configId) external view returns (LPConfig memory) {
        if (configId >= configCount) revert InvalidConfig();
        return lpConfigs[configId];
    }
    
    function _getReservesView(
        address pair,
        address tokenA,
        address tokenB
    ) private view returns (uint256 reserveA, uint256 reserveB) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        
        // 验证传入的tokenA和tokenB确实是pair的代币
        require(
            (token0 == tokenA && token1 == tokenB) || 
            (token0 == tokenB && token1 == tokenA),
            "Invalid token pair"
        );
        
        if (token0 == tokenA) {
            reserveA = uint256(reserve0);
            reserveB = uint256(reserve1);
        } else {
            reserveA = uint256(reserve1);
            reserveB = uint256(reserve0);
        }
    }
    
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    function getNativeBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    receive() external payable {}
}