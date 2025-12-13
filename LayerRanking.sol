// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title 分层排名系统
 * @dev 六层结构，新社区只能加第六层，门槛只升不降
 */
contract LayerRanking {
    // 六层定义
    uint256 internal constant LAYER_TOP10 = 1;
    uint256 internal constant LAYER_TOP30 = 2;  
    uint256 internal constant LAYER_TOP100 = 3;
    uint256 internal constant LAYER_TOP300 = 4;
    uint256 internal constant LAYER_TOP600 = 5;
    uint256 internal constant LAYER_TOP1000 = 6;
    
    // 各层级容量配置 [10, 20, 70, 200, 300, 400]
    uint256[6] internal layerCapacities = [10, 20, 70, 200, 300, 400];

    // 🎯各层级已发放奖励人数计数器
    mapping(uint256 => uint256) internal layerRewardCounters;

    // 入榜社区总量
    uint256 internal _totalRankedCommunities;
    
    // 数据结构
    mapping(uint256 => address[]) internal _layerCommunities;
    mapping(uint256 => uint256) internal layerSizes;
    mapping(address => uint256) internal communityLayer;
    mapping(address => uint256) internal _communityPerformance;
    
    // 六个层级的最低门槛
    uint256[6] internal layerThresholds = [
        5e11,  // 第1层门槛
        2e11,  // 第2层门槛  
        1e11,  // 第3层门槛
        5e10,  // 第4层门槛
        2e10,  // 第5层门槛
        1e10   // 第6层门槛
    ];

    // 分层奖励配置
    mapping(uint256 => uint256) internal layerRewards;

    // 防重复奖励：记录社区在哪些层级已经获得过奖励
    mapping(address => mapping(uint256 => bool)) internal rewardedLayers;
    
    /**
     * @dev 社区信息结构体
     */
    struct CommunityInfo {
        address community;
        uint256 performance;
    }

    // ==================== 事件定义 ====================
    event CommunityRanked(address indexed community, uint256 layer, uint256 performance, uint256 timestamp);
    event CommunityPromoted(address indexed community, uint256 fromLayer, uint256 toLayer, uint256 performance, uint256 timestamp);
    event LayerRewardDistributed(address indexed community, uint256 layer, uint256 rewardAmount, uint256 timestamp);
    error InvalidSerialLayer();
    error InvalidCommunity();
    constructor() {
        // Top分层奖励金额
        layerRewards[LAYER_TOP10]   = 50000e6;   // 前10名：  50000 VID
        layerRewards[LAYER_TOP30]   = 20000e6;   // 前30名：  20000 VID  
        layerRewards[LAYER_TOP100]  = 10000e6;   // 前100名： 10000 VID 
        layerRewards[LAYER_TOP300]  = 5000e6;    // 前300名： 5000  VID 
        layerRewards[LAYER_TOP600]  = 2000e6;    // 前600名： 2000  VID 
        layerRewards[LAYER_TOP1000] = 1000e6;    // 前1000名：1000  VID
    }
    /**
     * @dev 更新社区业绩 - 核心入口
     */
    function updateCommunityPerformance(address community, uint256 addedPerformance) internal {
        _communityPerformance[community] += addedPerformance;
        
        uint256 currentLayer = communityLayer[community];
        uint256 newPerformance = _communityPerformance[community];
        
        if (currentLayer == 0) {
            // 新社区
            _joinLayer6(community, newPerformance);
        } else {
            // 老社区
            _tryPromoteOneLayer(community, currentLayer, newPerformance);
        }
    }
    
    /**
     * @dev 新社区加入第六层
     */
    function _joinLayer6(address community, uint256 performance) private {
        // 检查是否达到第六层门槛
        if (performance < layerThresholds[5]) {
            return; // 不入榜
        }
        
        uint256 layer6Size = layerSizes[6];
        
        if (layer6Size < layerCapacities[5]) {
            // 第六层未满，直接加入
            _layerCommunities[6].push(community);
            layerSizes[6]++;
            communityLayer[community] = 6;
            //更新入榜社区总量
            _updateTotalRankedCache();

            emit CommunityRanked(community, 6, performance, block.timestamp);

            // 发放第六层奖励（仅限层级未满情况）
            if (!rewardedLayers[community][6]) {
                _distributeLayerReward(community, LAYER_TOP1000);
            }

            // 检查加入后是否满员
            if (layerSizes[6] >= layerCapacities[5]) {
                _updateThresholdIfNeeded(6);
            }

        } else {
            // 第六层已满，找到业绩最低的社区进行比较
            address minCommunity = _findMinPerformanceCommunity(6);
            uint256 minPerformance = _communityPerformance[minCommunity];
            
            if (performance >= minPerformance) {
                // 直接替换
                _replaceCommunityInArray(minCommunity, community, 6);
                communityLayer[community] = 6;
                communityLayer[minCommunity] = 0;

                emit CommunityRanked(community, 6, performance, block.timestamp);
                
                // 更新门槛（只升不降）
                _updateThresholdIfNeeded(6);
            }
        }
    }
    
    /**
     * @dev 老社区尝试晋升一层
     */
    function _tryPromoteOneLayer(address community, uint256 currentLayer, uint256 newPerformance) private {
        // 检查是否已在最高层
        if (currentLayer == 1) return;
        
        uint256 targetLayer = currentLayer - 1;
        
        // 检查是否达到目标层门槛
        if (newPerformance < layerThresholds[targetLayer - 1]) {
            return;
        }
        
        // 如果目标层未满，直接晋升
        if (layerSizes[targetLayer] < layerCapacities[targetLayer - 1]) {
            _promoteDirectly(community, currentLayer, targetLayer);
            return;
        }
        
        // 目标层已满，找到业绩最低的社区进行比较
        address minCommunity = _findMinPerformanceCommunity(targetLayer);
        uint256 minPerformance = _communityPerformance[minCommunity];
        
        // 比较业绩
        if (newPerformance >= minPerformance) {
            _swapCommunities(community, currentLayer, minCommunity, targetLayer);
        }
    }
    
    /**
     * @dev 直接晋升到目标层级（目标层未满的情况）
     */
    function _promoteDirectly(address community, uint256 fromLayer, uint256 toLayer) private {
        // 从原层级移除
        _removeFromLayer(community, fromLayer);
        
        // 加入目标层级
        _layerCommunities[toLayer].push(community);
        layerSizes[toLayer]++;
        communityLayer[community] = toLayer;
        
        // 更新门槛
        _updateThresholdIfNeeded(fromLayer);
        _updateThresholdIfNeeded(toLayer);

        emit CommunityPromoted(community, fromLayer, toLayer, _communityPerformance[community], block.timestamp);

        // 晋升时发放新层级的奖励 ✅
        if (!rewardedLayers[community][toLayer]) {
            _distributeLayerReward(community, toLayer);
        }
    }
    
    /**
     * @dev 社区互换（两层都满员的情况）
     */
    function _swapCommunities(address communityA, uint256 layerA, address communityB, uint256 layerB) private {
        // 直接替换数组中的元素，不改变数组长度和大小
        _replaceCommunityInArray(communityA, communityB, layerA);
        _replaceCommunityInArray(communityB, communityA, layerB);
        
        communityLayer[communityA] = layerB;
        communityLayer[communityB] = layerA;
        emit CommunityPromoted(communityA, layerA, layerB, _communityPerformance[communityA], block.timestamp);
        emit CommunityPromoted(communityB, layerB, layerA, _communityPerformance[communityB], block.timestamp);
        // 更新门槛 - 两层都保持满员，需要更新门槛
        _updateThresholdIfNeeded(layerA);
        _updateThresholdIfNeeded(layerB);
    }
    
    /**
     * @dev 在数组中直接替换社区 - 核心函数
     */
    function _replaceCommunityInArray(address oldCommunity, address newCommunity, uint256 layer) private {
        address[] storage communities = _layerCommunities[layer];
        
        for (uint256 i = 0; i < communities.length; i++) {
            if (communities[i] == oldCommunity) {
                communities[i] = newCommunity;
                return;
            }
        }
        revert InvalidCommunity();
    }
    
    /**
     * @dev 从层级中移除社区
     */
    function _removeFromLayer(address community, uint256 layer) private {
        address[] storage communities = _layerCommunities[layer];
        
        for (uint256 i = 0; i < communities.length; i++) {
            if (communities[i] == community) {
                // 与最后一个元素交换然后pop
                communities[i] = communities[communities.length - 1];
                communities.pop();
                layerSizes[layer]--;
                communityLayer[community] = 0;
                return;
            }
        }
    }

    /**
     * @dev 找到层级中业绩最低的社区 - 修复版本
     */
    function _findMinPerformanceCommunity(uint256 layer) private view returns (address) {
        if(layerSizes[layer] == 0) revert();
        
        address[] storage communities = _layerCommunities[layer];
        address minCommunity = communities[0];
        uint256 minPerformance = _communityPerformance[minCommunity];

        for (uint256 i = 1; i < layerSizes[layer]; i++) {
            address current = communities[i];
            uint256 currentPerformance = _communityPerformance[current];
            if (currentPerformance < minPerformance) {
                minCommunity = current;
                minPerformance = currentPerformance;
            }
        }
        
        return minCommunity;
    }
    
    /**
     * @dev 更新门槛（只在满员且需要时更新）
     */
    function _updateThresholdIfNeeded(uint256 layer) private {
        // 只在层级满员时更新门槛
        if (layerSizes[layer] < layerCapacities[layer - 1]) {
            return;
        }
        
        // 找到当前层级最低业绩
        address minCommunity = _findMinPerformanceCommunity(layer);
        uint256 newThreshold = _communityPerformance[minCommunity];
        
        // 只升不降 - 确保门槛反映真实的最低业绩
        if (newThreshold > layerThresholds[layer - 1]) {
            layerThresholds[layer - 1] = newThreshold;
        }
    }
    // 入榜社区数量更新函数
    function _updateTotalRankedCache() private {
        if (_totalRankedCommunities >= 1000) {
            return;
        }
        
        uint256 total = 0;
        for (uint256 layer = 1; layer <= 6; layer++) {
            total += layerSizes[layer];
        }
        if(total > _totalRankedCommunities){
            _totalRankedCommunities = total;
        }
    }

    //入榜社区奖励发放核心函数
    function _distributeLayerReward(address community, uint256 layer) private {
        // 检查是否已经在该层级获得过奖励
        if (rewardedLayers[community][layer]) {
            return;
        }
        // 🎯检查该层级已发放奖励人数是否超过容量限制
        if (layerRewardCounters[layer] >= layerCapacities[layer - 1]) {
            return;
        }
        uint256 rewardAmount = layerRewards[layer];

        if (rewardAmount > 0) {
            rewardedLayers[community][layer] = true;
            //增加该层奖励人数
            layerRewardCounters[layer]++;
            emit LayerRewardDistributed(community, layer, rewardAmount, block.timestamp);
            // 调用函数发放奖励
            _onRewardDistributed(community, rewardAmount);
        }
    }

    // 空实现函数
    function _onRewardDistributed(address community, uint256 rewardAmount) internal virtual {

    }

    //社区共振VID额外奖励加成
    function _applyRankBonus(address _community) internal view returns (uint256) {
        uint256 layer = communityLayer[_community];
        
        if (layer == LAYER_TOP10) return 300;
        if (layer == LAYER_TOP30) return 200;
        if (layer == LAYER_TOP100) return 150;
        if (layer == LAYER_TOP300) return 130;
        if (layer == LAYER_TOP600) return 120;
        if (layer == LAYER_TOP1000) return 110;
        //未上榜
        return 100;
    }

    //上榜社区加成奖励函数
    function _getCommunityRanking(address _community) internal view returns (uint256) {

        uint256 layer = communityLayer[_community];
        
        if (layer == LAYER_TOP10) return 200;
        if (layer == LAYER_TOP30) return 100;
        if (layer == LAYER_TOP100) return 50;
        if (layer == LAYER_TOP300) return 30;
        if (layer == LAYER_TOP600) return 20;
        if (layer == LAYER_TOP1000) return 10;
        //上榜社区不足1000时，社区倍率
        if (_totalRankedCommunities < 1000) return 1;
        //上榜社区达到1000名后只限上傍社区有奖励
        return 0;
    }

    // ========================== 查询函数 ===========================
    
    /**
    * @dev 计算全局排名
    */
    function _calculateGlobalRank(address community, uint256 performance) internal view returns (uint256) {
        uint256 rank = 1; // 排名从1开始
        
        // 遍历所有更高层级的社区
        for (uint256 l = 1; l < communityLayer[community]; l++) {
            rank += layerSizes[l];
        }
        
        // 在当前层级中计算排名
        uint256 currentLayer = communityLayer[community];
        address[] storage communities = _layerCommunities[currentLayer];

        for (uint256 i = 0; i < layerSizes[currentLayer]; i++) {
            if (_communityPerformance[communities[i]] > performance) {
                rank++;
            }
        }
        
        return rank;
    }

    /**
    * @dev 计算层级内排名
    */
    function _calculateLayerRank(uint256 layer, uint256 performance) internal view returns (uint256, uint256) {
        address[] storage communities = _layerCommunities[layer];
        uint256 betterCount = 0;

        for (uint256 i = 0; i < layerSizes[layer]; i++) {
            if (_communityPerformance[communities[i]] > performance) {
                betterCount++;
            }
        }
        
        return (betterCount + 1, layerSizes[layer]);
    }

    // 获取指定层级最高业绩
    function _getLayerTopPerformance(uint256 layer) internal view returns (uint256) {
        if (layerSizes[layer] == 0) return 0;
        
        address[] storage communities = _layerCommunities[layer];
        uint256 maxPerformance = 0;
        
        for (uint256 i = 0; i < layerSizes[layer]; i++) {
            uint256 perf = _communityPerformance[communities[i]];
            if (perf > maxPerformance) {
                maxPerformance = perf;
            }
        }
        return maxPerformance;
    }

    // 获取指定层级最低业绩
    function _getLayerMinPerformance(uint256 layer) internal view returns (uint256) {
        if (layerSizes[layer] == 0) return 0;
        
        address[] storage communities = _layerCommunities[layer];
        uint256 minPerformance = type(uint256).max;
        
        for (uint256 i = 0; i < layerSizes[layer]; i++) {
            uint256 perf = _communityPerformance[communities[i]];
            if (perf < minPerformance) {
                minPerformance = perf;
            }
        }
        return minPerformance;
    }

    // 降序排序辅助函数
    function _sortDescending(uint256[] memory array) internal pure {
        uint256 n = array.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (array[j] < array[j + 1]) {
                    (array[j], array[j + 1]) = (array[j + 1], array[j]);
                }
            }
        }
    }

}