// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

 /**
 * @title 社区管理系统
 * @dev 独立管理社区成员的加入、查询和统计功能
 */
contract CommunityManager {
    // 社区数据结构
    struct CommunityMap {
        address[] members;
        mapping(address => uint) indexOf;
    }

    CommunityMap internal community;

    // ==================== 事件定义 ====================
    event CommunityJoined(address indexed member, uint256 totalMembers, uint256 mintingFee, uint256 timestamp);
    error InvalidSerialIndex();

    function isCommunityMember(address account) internal view returns (bool) {
        return community.indexOf[account] != 0;
    }

    function getCommunityMemberAtIndex(uint index) internal view returns (address) {
        if(index >= community.members.length)revert InvalidSerialIndex();
        return community.members[index];
    }

    function _addToCommunity(address account) internal {
        if (community.indexOf[account] == 0) {
            community.indexOf[account] = community.members.length + 1;
            community.members.push(account);
            emit CommunityJoined(account, community.members.length, getCommunityMintingFee(), block.timestamp);
        }
    }

    function _removeFromCommunity(address account) internal {
        uint storedIndex = community.indexOf[account];
        if (storedIndex == 0) return;
        
        uint index = storedIndex - 1;
        uint lastIndex = community.members.length - 1;
        
        if (index != lastIndex) {
            address lastMember = community.members[lastIndex];
            community.members[index] = lastMember;
            community.indexOf[lastMember] = index + 1;
        }
        
        community.members.pop();
        delete community.indexOf[account];
    }

    // ============================ 查询区域 ===================================

    //获取全网社区数量
    function getMemberCount() public view returns (uint) {
        return community.members.length;
    }

    // 创建社区一次性所需铸造Vollar的数量
    function getCommunityMintingFee() internal view returns (uint256) {

        uint256 communityCount = getMemberCount();
        
        // 前10个社区固定1000 Vollar
        if (communityCount <= 10) {
            return 1000e6;
        }
        
        // 从第11个开始，每个增加1个社区增加100
        uint256 extraCommunities = communityCount - 10;
        uint256 extraFee = extraCommunities * 100e6;
        uint256 totalFee = 1000e6 + extraFee;
        
        //申请社区铸造Vollar数量到1万封顶
        return totalFee > 10000e6 ? 10000e6 : totalFee;
    }


}