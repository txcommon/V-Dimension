// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./MathUtils.sol";

library InterestRate {
    using MathUtils for uint256;
    //生息利率计算
    function getInterestRate(uint256 totalSupply) internal pure returns (uint256) {
        // 第一阶段：基础供应量以下，固定利率2%
        if (totalSupply < MathUtils.BASE_SUPPLY) {
            return 200;  // 2.00%
        }
        // 第二阶段：1亿以下，固定利率10%
        else if (totalSupply < MathUtils.baseBillion) {
            return 1000; // 10.00%
        }
        // 第三阶段：1亿到10亿之间，利率从10%线性递减到5%
        else if (totalSupply < 10 * MathUtils.baseBillion) {
            uint256 increaseAmount = totalSupply - MathUtils.baseBillion;
            uint256 decreaseUnits = increaseAmount / (180 * MathUtils.base10000);
            uint256 result = 1000 - decreaseUnits;
            return result > 500 ? result : 500;
        }
        // 第四阶段：10亿到100亿之间，利率从5%线性递减到2%
        else if (totalSupply < 100 * MathUtils.baseBillion) {
            uint256 increaseAmount = totalSupply - (10 * MathUtils.baseBillion);
            uint256 decreaseUnits = increaseAmount / (3000 * MathUtils.base10000);
            uint256 result = 500 - decreaseUnits;
            return result > 200 ? result : 200;
        }
        // 第五阶段：100亿到5000亿之间，固定利率2%
        else if (totalSupply < 5000 * MathUtils.baseBillion) {
            return 200;
        }
        // 第六阶段：5000亿到10000亿之间，利率从2%线性递减到0%
        else if (totalSupply < 10000 * MathUtils.baseBillion) {
            uint256 increaseAmount = totalSupply - 5000 * MathUtils.baseBillion;
            uint256 decreaseUnits = increaseAmount / (25 * MathUtils.baseBillion);
            uint256 result = 200 - decreaseUnits;
            return result > 0 ? result : 0;
        }
        // 第七阶段：10000亿以上，零利率
        else {
            return 0;
        }
    }
}