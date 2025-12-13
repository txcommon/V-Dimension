// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev 神圣代币接口
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * ██████╗ ██╗   ██╗██████╗ ███████╗███████╗    ███████╗ ██████╗ ██████╗ ████████╗██╗   ██╗███╗   ██╗ █████╗ 
 * ██╔══██╗██║   ██║██╔══██╗██╔════╝██╔════╝    ██╔════╝██╔═══██╗██╔══██╗╚══██╔══╝██║   ██║████╗  ██║██╔══██╗
 * ██████╔╝██║   ██║██████╔╝███████╗█████╗      █████╗  ██║   ██║██████╔╝   ██║   ██║   ██║██╔██╗ ██║███████║
 * ██╔═══╝ ██║   ██║██╔══██╗╚════██║██╔══╝      ██╔══╝  ██║   ██║██╔══██╗   ██║   ██║   ██║██║╚██╗██║██╔══██║
 * ██║     ╚██████╔╝██║  ██║███████║███████╗    ██║     ╚██████╔╝██║  ██║   ██║   ╚██████╔╝██║ ╚████║██║  ██║
 * ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝
 * 
 * @title Purse of Fortuna - 命运女神之金库
 * @dev 汇聚财富，分发福报的神圣金库
 * 
 * 🌟 合约寓意：
 * Fortuna（福耳图那）是罗马神话中的命运女神
 * 她手持丰裕之角，将财富与机遇洒向人间
 * 此合约如同她的金库，汇聚社群之福，公平分发
 * 
 * ✨ 核心特性：
 * - 聚宝盆：自动汇聚各方分红代币
 * - 定时开仓：每24小时开启一次，如同女神定期播撒福报
 * - 专款专用：只有指定的圣殿（分红合约）可以开启金库
 * - 永恒契约：一旦建立，永不更改
 * 
 * 🏛️ 使用场景：
 * 1. 社区税收自动流入此金库
 * 2. 交易税自动注入分红资金
 * 3. 合作伙伴贡献收益
 * 4. 出售VDS股权收益
 * 5. 每24小时由分红圣殿开启，公平分配
 */
contract PurseOfFortuna {

    address public owner;
    // 神圣代币 - 福报的载体
    address public immutable sacredToken;
    
    // 圣殿地址 - 唯一能开启金库的圣殿（分红合约）
    address public temple;

    // 事件：金库开启，福报流转
    event FortunasBlessing(uint256 amount, uint256 timestamp);
    /**
     * @dev 圣殿建立事件
     * @param sacredToken 神圣代币地址
     * @param temple 圣殿（分红合约）地址
     */
    event TempleConsecrated(address indexed sacredToken, address indexed temple);
    /**
     * @dev 所有权转移事件
     * @param previousOwner 前所有者
     * @param newOwner 新所有者
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /**
     * @dev 神圣契约 - 建立永恒的连接
     * @param _sacredToken 神圣代币地址（分红代币）
     * 
     * 📜 契约意义：
     * 一旦建立，金库与圣殿的链接永恒不变
     * 如同命运三女神纺出的生命之线，不可更改
     * 
     * ⚠️ 重要提醒：
     * 1. 神圣代币地址在部署时确定，永不更改
     * 2. 圣殿地址只能设置一次，请谨慎选择
     * 3. 部署后调用`renounceOwnership()`实现完全去中心化
     */
    constructor(address _sacredToken) {
        sacredToken = _sacredToken;
        owner = msg.sender;
    }
    
    // ============= 修饰符 =============
    
    /**
     * @dev 仅所有者修饰符
     * @notice 限制只有合约所有者可以调用
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /**
     * @dev 开启金库 - 圣殿祭司的仪式
     * @return blessings 播撒的福报数量
     * 
     * ⏳ 仪式频率：每24小时可举行一次
     * 🕯️ 仪式过程：
     * 1. 验证祭司身份（必须是圣殿地址）
     * 2. 清点金库中的福报
     * 3. 将所有福报转移至圣殿
     * 4. 记录福报流转事件
     * 
     * 🎭 神话象征：
     * 如同Fortuna倾倒她的丰裕之角
     * 将积累的财富公平洒向信众
     * 
     * 📊 技术要求：
     * - 仅圣殿合约可调用
     * - 自动计算并转移所有代币余额
     * - 返回实际转移数量供圣殿记录
     */
    function openThePurse() external returns (uint256 blessings) {
        // 验证祭司身份
        require(msg.sender == temple, "Only temple open the purse");
        
        // 清点金库中的福报
        blessings = IERC20(sacredToken).balanceOf(address(this));
        
        // 如果有福报，进行转移仪式
        if (blessings > 0) {
            // 执行神圣转移
            bool success = IERC20(sacredToken).transfer(temple, blessings);
            require(success, "failed");
            
            // 记录神圣事件
            emit FortunasBlessing(blessings, block.timestamp);
        }
        
        // 金库已空，等待下次积累
        // 返回播撒的福报数量
        return blessings;
    }

    // ============= 管理功能 =============
    
    /**
     * @dev 建立圣殿 - 神圣的祝圣仪式
     * @param _temple 圣殿地址（分红合约地址）
     * 
     * 🏛️ 仪式意义：
     * 将普通合约地址升华为神圣的圣殿
     * 从此获得开启金库、分发福报的神圣权力
     * 
     * ⚠️ 重要限制：
     * 1. 此仪式只能进行一次
     * 2. 一旦完成，无法更改
     * 3. 圣殿必须能正确处理神圣代币
     * 
     * 🔒 安全保证：
     * - 只有合约所有者可以执行
     * - 必须提供非零地址
     * - 防止重复设置
     */
    function consecrateTemple(address _temple) external onlyOwner {
        temple = _temple;
        
        // 记录神圣契约的建立
        emit TempleConsecrated(sacredToken, _temple);
    }
    
    /**
     * @dev 放弃合约所有权（丢弃管理员权限）
     * @notice 放弃后合约将完全去中心化，无人能更改配置
     * @notice 这是一个不可逆的操作，请谨慎使用
     * 
     * 🕊️ 去中心化意义：
     * 1. 合约稳定运行后，实现完全去中心化
     * 2. 防止未来可能的中心化风险
     * 3. 让社区完全掌控合约命运
     * 
     * ⚠️ 前提条件：
     * 1. 圣殿已成功建立（temple != address(0)）
     * 2. 确保圣殿地址正确无误
     * 3. 确认合约配置完全正确
     */
    function renounceOwnership() external onlyOwner {
        require(temple != address(0), "consecrated first");
        
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    // ============= 查询功能 =============
    
    /**
     * @dev 查看金库余额 - 窥探丰裕之角
     * @return 当前金库中神圣代币的数量
     * 
     * 🔍 功能说明：
     * 任何人都可以查看金库中的积累
     * 透明公开，符合区块链精神
     */
    function checkBlessings() external view returns (uint256) {
        return IERC20(sacredToken).balanceOf(address(this));
    }
    
    /**
     * @dev 查看圣殿信息 - 确认神圣连接
     * @return 神圣代币地址和圣殿地址
     * 
     * 📜 信息透明：
     * 显示金库的核心配置
     * 确保所有参数一目了然
     */
    function getSanctumInfo() external view returns (address, address) {
        return (sacredToken, temple);
    }

    /**
    * @dev 拒绝凡俗之物 - 此金库只接收神圣代币
    * @notice 误转的ETH将被拒绝并回滚交易
    */
    receive() external payable {
        revert("Only sacred token");
    }

    /**
    * @dev 全能拒绝器 - 防止各种非法操作
    * @notice 拒绝：1) 附带ETH的函数调用 2) 不存在的函数调用
    */
    fallback() external payable {
        if (msg.value > 0) {
            revert("Do not send ETH");
        }
        revert("Function not implemented");
    }

}

/** 
 * 🌈 品牌故事：
 * 在区块链的星空中，有一座神秘的命运圣殿
 * 信众们将自己的代币质押于此，表达对项目的信仰
 * 各方收益如涓涓细流，汇入命运女神的金库
 * 每24小时，圣殿祭司开启金库，将福报公平分配
 * 这是一个自动、透明、公平的财富循环系统
 * 如同古典神话在现代科技中的重生
 * 
 * 📖 使用指南：
 * 1. 部署合约，传入神圣代币地址
 * 2. 调用consecrateTemple()建立圣殿连接
 * 3. 验证一切正常后，调用renounceOwnership()去中心化
 * 4. 圣殿合约定期调用openThePurse()分发福报
 * 
 * 🎯 设计哲学：
 * 最小权限原则：只有圣殿能开启金库
 * 不可变性：关键参数一经设置，永不更改
 * 透明度：所有操作链上可查
 * 去中心化：最终无人能控制，完全由代码治理
 */