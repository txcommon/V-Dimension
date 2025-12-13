// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./MathUtils.sol";

library QuotaCalculator {

    using MathUtils for uint256;

    //VID释放额度计算
    function getVIDQuota(uint256 currentSupply) internal pure returns (uint256) {

        if (currentSupply > 333 * MathUtils.baseBillion) {
            return MathUtils.MAX_SUPPLY;
        }

        return _calculateQuota(currentSupply);
    }

    function _calculateQuota(uint256 targetSupply) private pure returns (uint256) {

        if (targetSupply <= MathUtils.BASE_SUPPLY) {
            return _calculateEarlyStageQuota(targetSupply);
        }
        if (targetSupply <= MathUtils.MAX_SUPPLY) {
            return _calculateFromBase(targetSupply);
        }
        if (targetSupply <= MathUtils.MAX_SUPPLY * 10) {
            return _calculateFrom10BTo100B(targetSupply);
        }
        if (targetSupply <= MathUtils.MAX_SUPPLY * 100) {
            return _calculateFrom100BTo1000B(targetSupply);
        }
        return MathUtils.MAX_SUPPLY;
    }

    function _calculateEarlyStageQuota(uint256 supply) private pure returns (uint256) {

        if (supply < 2 * MathUtils.baseMillion) return 5 * MathUtils.base10000;

        if (supply < 5 * MathUtils.baseMillion) {
            uint256 stages = (supply - 2 * MathUtils.baseMillion) / MathUtils.baseMillion;
            return (10 * MathUtils.base10000) + (stages * 5 * MathUtils.base10000);
        }

        if (supply < 11 * MathUtils.baseMillion) {
            uint256 stages = (supply - 5 * MathUtils.baseMillion) / MathUtils.baseMillion;
            return (25 * MathUtils.base10000) + (stages * 10 * MathUtils.base10000);
        }

        if (supply <= MathUtils.BASE_SUPPLY) {
            uint256 stages = (supply - 11 * MathUtils.baseMillion) / MathUtils.baseMillion;
            return (85 * MathUtils.base10000) + (stages * 30 * MathUtils.base10000);
        }

        return 385 * MathUtils.base10000;
    }

    function _calculateFromBase(uint256 targetSupply) private pure returns (uint256) {

        uint256 currentSupply = MathUtils.BASE_SUPPLY;
        uint256 currentQuota = 385 * MathUtils.base10000;
        
        while (currentSupply + MathUtils.SUPPLY_STEP <= targetSupply) {

            uint256 currentPrice = _getExactPrice(currentSupply);
            uint256 baseIncrement = MathUtils.SUPPLY_STEP / currentPrice;
            uint256 actualIncrement = (baseIncrement * 20) / 100;

            currentQuota += actualIncrement;
            currentSupply += MathUtils.SUPPLY_STEP;

            if (currentSupply > MathUtils.MAX_SUPPLY) {
                break;
            }
        }
        return currentQuota;
    }

    function _calculateFrom10BTo100B(uint256 targetSupply) private pure returns (uint256) {

        uint256 currentSupply = MathUtils.MAX_SUPPLY;
        uint256 currentQuota = 7071222464927;
        
        while (currentSupply + (10 * MathUtils.SUPPLY_STEP) <= targetSupply) {

            uint256 currentPrice = _getExactPrice(currentSupply);
            uint256 baseIncrement = MathUtils.SUPPLY_STEP * 10 / currentPrice;
            uint256 actualIncrement = (baseIncrement * 25) / 100;

            currentQuota += actualIncrement;
            currentSupply += MathUtils.SUPPLY_STEP * 10;

            if (currentSupply > MathUtils.MAX_SUPPLY * 10) {
                break;
            }
        }
        return currentQuota;
    }

    function _calculateFrom100BTo1000B(uint256 targetSupply) private pure returns (uint256) {

        uint256 currentSupply = MathUtils.MAX_SUPPLY * 10;
        uint256 currentQuota = 8819421008328;
        
        while (currentSupply + (100 * MathUtils.SUPPLY_STEP) <= targetSupply) {

            uint256 currentPrice = _getExactPrice(currentSupply);
            uint256 baseIncrement = MathUtils.SUPPLY_STEP * 100 / currentPrice;
            uint256 actualIncrement = (baseIncrement * 30) / 100;

            currentQuota += actualIncrement;
            currentSupply += MathUtils.SUPPLY_STEP * 100;

            if (currentSupply > MathUtils.MAX_SUPPLY * 100) {
                break;
            }
        }
        return currentQuota;
    }
    //单价计算
    function _getExactPrice(uint256 supply) private pure returns (uint256) {

        if (supply < MathUtils.BASE_SUPPLY) {
            return 1;
        }

        return ((supply - MathUtils.BASE_SUPPLY) / MathUtils.SUPPLY_STEP) + 2;
    }

    //USDT释放额度计算
    function getUSDTAllocation(uint256 supply) internal pure returns (uint256) {

        if (supply < MathUtils.baseBillion) return 0;

        if (supply <= 111 * MathUtils.baseBillion) {
            uint256 steps1 = (supply - MathUtils.baseBillion) / MathUtils.baseBillion;
            return (steps1 + 1) * 15000000e18;
        }
        
        if (supply <= 222 * MathUtils.baseBillion) {
            uint256 steps2 = (supply - 111 * MathUtils.baseBillion) / MathUtils.baseBillion;
            uint256 firstSegmentTotal = 111 * 15000000e18;
            uint256 secondSegmentCurrent = (steps2 + 1) * 20000000e18;
            return firstSegmentTotal + secondSegmentCurrent;
        }
        
        uint256 steps3 = (supply - 222 * MathUtils.baseBillion) / MathUtils.baseBillion;
        uint256 secondSegmentTotal = 3905000000e18;
        uint256 thirdSegmentCurrent = steps3 * 30000000e18;
        return secondSegmentTotal + thirdSegmentCurrent;
    }
}