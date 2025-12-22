// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract UserDataManager {

    // ==================== 新人授权保护 ====================

    //新人授权保护结构体
    struct UserApprovalState {
        uint256 currentLimit;
        uint256 usageCount;
    }

    //新人授权状态映射
    mapping(address => UserApprovalState) internal userStates;

    // 全网利率和税率统计结构体
    struct RateStats {
        uint256 mintRate;                    // 兑换单价
        uint256 tokenTax;                    // 转账税率
        uint256 interestRate;                // 生息利率
        uint256 vidQuota;                    // VID配额
        uint256 usdtAllocation;              // USDT配额
    }

    // ==================== 用户个人信息 ====================

    mapping(address => bool) internal holdingInterest;         //个人持币生息权限
    mapping(address => bool) internal dangerousAddresses;      //限制转账PAIR地址
    mapping(address => uint256) internal interestTime;         //个人生息时间表
    mapping(address => uint256) internal bnbTime;              //Vollar兑换BNB时间表
    mapping(address => uint256) internal usdtTime;             //Vollar兑换USDT时间表
    mapping(address => uint256) internal vidTime;              //Vollar兑换VID时间表
    mapping(address => uint256) internal uSwapVTime;           //社区USDT兑换VID时间表

    // 全网数据统计结构体
    struct GlobalStats {
        uint256 startTimer;                // 合约启动时间
        uint256 userCount;                 // 共振参与人数

        //全网Vollar铸造统计
        uint256 allTotalAmount;            // 全网铸造总量
        uint256 allVIDMintedVollar;        // VID铸造总量
        uint256 allUSDTMintedVollar;       // USDT铸造总量
        uint256 allCompoundInterest;       // 生息铸造总量

        //全网共振统计
        uint256 allTotalVIDResonance;      // VID共振总量
        uint256 allTotalUSDTResonance;     // USDT共振总量

        //全网推广奖励VID统计
        uint256 allVIDRewardAmount;        // 奖励VID总量
        
        //全网社区USDT兑换VID统计
        uint256 totalUSDTReceived;         // USDT兑入总额
        uint256 totalRedeemedVID;          // VID兑出总额

        //全网Vollar兑换资产统计
        uint256 allBNBWithdrawn;           // 兑换BNB总量
        uint256 allUSDTWithdrawn;          // 兑换USDT总量
        uint256 allVIDWithdrawn;           // 兑换VID总量

        //全网兑换资产销毁Vollar统计
        uint256 allTotalAmountS;           // 社区销毁总量
        
    }

    //声明结构体变量：
    GlobalStats internal globalStats;

    // 用户信息结构体
    struct UserInfo {
        //获得Vollar统计
        uint256 totalMintedVollar;            // 个人铸造总额
        uint256 vollarFromVID;                // VID共振获得
        uint256 vollarFromUSDT;               // USDT共振获得
        uint256 personalHoldingInterest;      // 持币生息获得
        uint256 communitySubsidyMint;         // 社区补贴获得
        //共振统计
        uint256 vidResonanceAmount;           // VID共振总额
        uint256 usdtResonanceAmount;          // USDT共振总额
        //推广奖励VID统计
        uint256 vidRewardsFromRef;            // 个人奖励VID
        uint256 vidRewardsFromCommunity;      // 社区奖励VID
        //USDT兑换VID统计(社区)
        uint256 usdtForVIDAmount;             // USDT兑换总额
        uint256 getTotalVID;                  // 兑换获得VID
        //Vollar兑换统计(社区)
        uint256 exchangedBNB;                 // 兑换BNB总额
        uint256 exchangedUSDT;                // 兑换USDT总额
        uint256 exchangedVID;                 // 兑换VID总额
        //兑换资产销毁Vollar统计
        uint256 exchangedBurnedVollar;        // 兑换销毁总额

    }

    //存储用户信息列表
    mapping(address => UserInfo) internal userInfo;

    // ==================== 综合更新方法 ====================

    /**
     * @dev VID共振完整数据更新
     * @param user 用户地址
     * @param actualMintAmount 实际铸造Vollar数量
     * @param vidAmount VID共振金额
     * @param communitySubsidy 社区补贴金额
     */
    function completeVIDResonanceUpdate(
        address user,
        uint256 actualMintAmount,
        uint256 vidAmount,
        uint256 communitySubsidy
    ) internal {
        UserInfo storage u = userInfo[user];
        
        // 更新用户数据
        u.totalMintedVollar += actualMintAmount;        //获得Vollar总金额
        u.vidResonanceAmount += vidAmount;              //共振VID金额
        if (communitySubsidy > 0){
            u.communitySubsidyMint += communitySubsidy;//社区补贴
            u.vollarFromVID += actualMintAmount - communitySubsidy; //基础铸造(扣除社区补贴)
        } else {u.vollarFromVID += actualMintAmount; }

        // 更新系统数据
        globalStats.allTotalAmount += actualMintAmount;
        globalStats.allTotalVIDResonance += vidAmount;
        globalStats.allVIDMintedVollar += actualMintAmount;

    }

    /**
     * @dev USDT共振完整数据更新
     * @param user 用户地址
     * @param mintAmount 铸造Vollar数量
     * @param usdtAmount USDT共振金额
     * @param communitySubsidy 社区补贴金额
     */
    function completeUSDTResonanceUpdate(
        address user,
        uint256 mintAmount,
        uint256 usdtAmount,
        uint256 communitySubsidy
    ) internal {
        UserInfo storage u = userInfo[user];
        
        // 更新用户数据
        u.totalMintedVollar += mintAmount;
        u.usdtResonanceAmount += usdtAmount;
        
        if (communitySubsidy > 0) {
            u.communitySubsidyMint += communitySubsidy;
            u.vollarFromUSDT += mintAmount - communitySubsidy;
        } else {u.vollarFromUSDT += mintAmount;}
        
        // 更新系统数据
        globalStats.allTotalAmount += mintAmount;
        globalStats.allTotalUSDTResonance += usdtAmount;
        globalStats.allUSDTMintedVollar += mintAmount;
        
    }

    /**
     * @dev 持币生息完整数据更新
     * @param user 用户地址
     * @param interestAmount 生息金额
     */
    function completeInterestUpdate(address user, uint256 interestAmount) internal {
        UserInfo storage u = userInfo[user];
        
        // 更新用户数据
        u.totalMintedVollar += interestAmount;
        u.personalHoldingInterest += interestAmount;
        
        // 更新系统数据
        globalStats.allCompoundInterest += interestAmount;
        globalStats.allTotalAmount += interestAmount;
        
        // 更新时间
        interestTime[user] = block.timestamp;
    }

    //推荐共振VID奖励更新
    function updateReferralReward(address user, uint256 amount, bool isCommunity) internal {
        UserInfo storage u = userInfo[user];
        
        if (isCommunity) {
            u.vidRewardsFromCommunity += amount;    //社区推荐VID奖励
        } else {
            u.vidRewardsFromRef += amount;          //普通推荐VID奖励
        }
        // 更新系统数据
        globalStats.allVIDRewardAmount += amount;
    }

    /**
     * @dev USDT兑换VID完整数据更新
     * @param user 用户地址
     * @param usdtAmount USDT金额
     * @param vidAmount VID金额
     */
    function completeUSDTToVIDUpdate(address user, uint256 usdtAmount, uint256 vidAmount) internal {
        UserInfo storage u = userInfo[user];
        
        // 更新用户数据
        u.usdtForVIDAmount += usdtAmount;
        u.getTotalVID += vidAmount;
        
        // 更新系统数据
        globalStats.totalUSDTReceived += usdtAmount;
        globalStats.totalRedeemedVID += vidAmount;
        
        // 更新时间
        uSwapVTime[user] = block.timestamp;
    }
    //更新Vollar兑换BNB数据
    function completeVollarForBNBUpdate(address user, uint256 amount, uint256 bnbAmount) internal {
        UserInfo storage u = userInfo[user];
        
        // 更新用户数据
        u.exchangedBurnedVollar += amount;
        u.exchangedBNB += bnbAmount;
        
        // 更新系统数据
        globalStats.allTotalAmountS += amount;
        globalStats.allBNBWithdrawn += bnbAmount;
        
        // 更新时间
        bnbTime[user] = block.timestamp;

    }

    //更新Vollar兑换USDT数据
    function completeVollarForUSDTUpdate(address user, uint256 amount, uint256 usdtAmount) internal {
        UserInfo storage u = userInfo[user];

        // 更新用户数据
        u.exchangedBurnedVollar += amount;
        u.exchangedUSDT += usdtAmount;

        // 更新系统数据
        globalStats.allTotalAmountS += amount;
        globalStats.allUSDTWithdrawn += usdtAmount;

        // 更新时间
        usdtTime[user] = block.timestamp;
    }

    //更新Vollar兑换VID数据
    function completeVollarForVIDUpdate(address user, uint256 amount, uint256 vidAmount) internal {
        UserInfo storage u = userInfo[user];        

        // 更新用户数据
        u.exchangedBurnedVollar += amount;
        u.exchangedVID += vidAmount;

        // 更新系统数据
        globalStats.allTotalAmountS += amount;
        globalStats.allVIDWithdrawn += vidAmount;

        // 更新时间
        vidTime[user] = block.timestamp;
    }

}
