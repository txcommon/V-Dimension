// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./MathUtils.sol";

library TokenExchange {

    using MathUtils for uint256;

    //领取生息费用计算
    function getBnbFee(uint256 totalSupply) internal pure returns (uint256) {

        uint256 billions = totalSupply / MathUtils.baseBillion;

        if (billions < 1000) {
            return 0.001 ether;

        } else if (billions < 5000) {

            uint256 decreaseAmount = ((billions - 1000) / 50) * 0.00001 ether;
            uint256 newFee = 0.001 ether - decreaseAmount;

            return newFee >= 0.0001 ether ? newFee : 0.0001 ether;

        } else {

            return 0.0001 ether;

        }
    }

    //VID兑换单价计算
    function getMintRate(uint256 totalSupply) internal pure returns (uint256) {
        
        if (totalSupply < MathUtils.BASE_SUPPLY) {
            return 1;
        }

        uint256 rate = (totalSupply - MathUtils.BASE_SUPPLY) / (3 * MathUtils.baseMillion) + 2;
        
        return rate;
    }

    //普通转账税率计算
    function getTokenTax(uint256 totalSupply) internal pure returns (uint256) {

        if (totalSupply < 1000 * MathUtils.baseBillion) {
            return 0;
        }

        uint256 taxRate = (totalSupply - 1000 * MathUtils.baseBillion) / (8 * MathUtils.baseBillion);

        return taxRate > 500 ? 500 : taxRate;

    }

    //社区额外补贴率计算
    function getSubsidyRate(uint256 totalSupply) internal pure returns (uint256) {

        uint256 millions = totalSupply / MathUtils.baseMillion;
        
        if (millions < 2) {
            return 900;
        } else if (millions < 10) {
            return 1000 - (millions * 100);
        } else if (millions < 21) {
            return 25;
        } else if (millions < 100) {
            return 10;
        } else {
            return 0;
        }
    }

}