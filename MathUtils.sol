// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

library MathUtils {
    
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
    
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // 基础单位定义 - 改为常量但保持原名
    uint256 internal constant baseOne = 1e6;          // 1 Vollar (1.000000)
    uint256 internal constant base10000 = 1e10;       // 10,000 Vollar (10,000.000000)
    uint256 internal constant baseMillion = 1e12;     // 1,000,000 Vollar (1,000,000.000000)
    uint256 internal constant baseBillion = 1e14;     // 100,000,000 Vollar (100,000,000.000000)
    uint256 internal constant BASE_SUPPLY = 21e12;    // 21,000,000 Vollar 基础供应量
    uint256 internal constant MAX_SUPPLY = 1e15;      // 10亿
    uint256 internal constant SUPPLY_STEP = 3e12;     // 300万
    uint256 internal constant maxVollarFee = 10e10;   // 单次封顶兑换量
    uint256 internal constant min1Amount = 1011e5;    // 绑定关系转账金额
    uint256 internal constant min2Amount = 100e6;     // 开启生息消耗金额

    uint256 internal constant communityLaunchTime = 1765166400;   // 燃烧开启时间2025-12-08 12:00:00
    uint256 internal constant genesisExchangeTime = 1767232800;   // 创世兑换时间2026-01-01 10:00:00

    //燃烧主币铸造参数
    uint256 internal constant minAmount = 1e5;
    uint256 internal constant maxAmount = 1e10;

    //燃烧USDT铸造参数
    uint256 internal constant token2MinAmount = 1e18;
    uint256 internal constant max2Amount = 1000000e18;

    //时间限制参数
    uint256 internal constant ReminTime = 8 hours;            //最小等待时间
    uint256 internal constant RemaxTime = 30 days;            //最大等待时间
    
    uint256 internal constant whiteRefRete1 = 500;    //社区基础奖励参数
    uint256 internal constant whiteRefRete2 = 150;    //社区平级奖励参数
    uint256 internal constant whiteRefRete3 = 50;     //社区领导奖励参数

    //动态奖参数
    uint256 internal constant refR1 = 500;
    uint256 internal constant refR2 = 300;
    uint256 internal constant refR3 = 200;

    //层级奖自有算力达标参数
    uint256 internal constant minB1 = 1000*10**6;
    uint256 internal constant minB2 = 3000*10**6;
    uint256 internal constant minB3 = 10000*10**6;

    // 定义兑换类型常量
    uint8 internal constant EXCHANGE_BNB = 0;
    uint8 internal constant EXCHANGE_USDT = 1; 
    uint8 internal constant EXCHANGE_VID = 2;

}