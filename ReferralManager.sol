// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title ReferralManager
 * @dev 推荐关系管理合约
 */
contract ReferralManager {

    // ==================== 状态变量 ====================
    
    // 上级推荐关系映射
    mapping(address => address) internal refs;
    
    // 下线第一代推荐地址组
    mapping(address => address[]) internal firstRecommendedList;

    // 下线第一代开启的生息映射
    mapping(address => uint256) internal directReferralInterestCount;
    
    // ==================== 自定义错误 ====================
    
    error AlreadyHasReferrer();            // 已有推荐人
    error InvalidReferrer();               // 无效的推荐人
    error SelfReferral();                  // 不能自己推荐自己
    error ContractAsReferrer();            // 合约地址作为推荐人
    error ZeroAddres();                    // 零地址
    error MaxDirectReferralsReached();     // 一级团队数量达到上限
    
    // ==================== 事件 ====================
    
    event ReferralBound(
        address indexed user, 
        address indexed referrer,
        uint256 timestamp
    );
    
    // ==================== 结构体 ====================

    struct MemberStatus {
        address memberAddress;    // 成员地址
        bool interestStatus;      // 生息状态（true: 开启, false: 关闭）
    }

    // 定义用户推荐利息状态结构体
    struct UserRefInterestStatus {
        address myReferrer;                   // 推荐地址
        address myReferrerCommunity;          // 推荐社区
        uint256 totalFirstLevelMembers;       // 成员总数  
        uint256 activeInterestCount;          // 生息人数
        MemberStatus[] memberStatuses;        // 成员状态数组（包含地址和生息状态）
    }

    // ==================== 核心函数 ====================

    function _bindReferral(address user, address ref) internal {
        
        // ==================== 第一层：基础验证 ====================
        
        // 检查用户地址有效性
        if (user == address(0) || ref == address(0)) revert ZeroAddres();
        if (refs[user] != address(0)) revert AlreadyHasReferrer();
        if (user == ref) revert SelfReferral();
        if (user == address(this)) revert InvalidReferrer();
        
        // ==================== 第二层：推荐人资格验证 ====================
        
        if (ref != address(this) && refs[ref] == address(0)) {
            revert InvalidReferrer();
        }

        // ==================== 一级团队数量限制 ====================

        if (firstRecommendedList[ref].length < 300) {
        
        // ==================== 执行绑定 ====================
            
            // 建立推荐关系
            refs[user] = ref;
            
            // 更新推荐人的直推列表
            firstRecommendedList[ref].push(user);
            
            // 发出事件
            emit ReferralBound(user, ref, block.timestamp);
        }
    }
    
    // ==================== 辅助查询函数 ====================
    
    /**
     * @dev 检查推荐人资格（外部调用）
     * @param ref 要检查的推荐人地址
     * @return bool 是否是有效的推荐人
     */
    function checkRefValid(address ref) external view returns (bool) {
        // 零地址无效
        if (ref == address(0)) {
            return false;
        }
        
        // 合约本身是有效的（顶级推荐人）
        if (ref == address(this)) {
            return true;
        }
        
        // 已有推荐人的用户是有效的
        return refs[ref] != address(0);
    }

}
