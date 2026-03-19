// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./MathUtils.sol";

library InterestRate {
    using MathUtils for uint256;
    //生息利率计算
    function getInterestRate(uint256 totalSupply) internal pure returns (uint256) {
        // 第一阶段：100亿供应量以下，月固定利率3%
        if (totalSupply < 100 * MathUtils.baseBillion) {
            return 300;  // 3.00%
        }
        // 第二阶段：100亿到1000亿之间，年利率从36%线性递减到6%
        else if (totalSupply < 1000 * MathUtils.baseBillion) {
            uint256 increaseAmount = totalSupply - 100 * MathUtils.baseBillion;
            uint256 decreaseUnits = increaseAmount / 36e13;
            uint256 result = 300 - decreaseUnits;
            return result > 50 ? result : 50;
        }
        // 第三阶段：1000亿以上，年利率6%
        else {
            return 50;
        }
    }
}
