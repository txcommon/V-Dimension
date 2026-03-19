// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./MathUtils.sol";

library TokenExchange {

    using MathUtils for uint256;

    //领取生息费用计算
    function getBnbFee(uint256 totalSupply) internal pure returns (uint256) {

        uint256 billions = totalSupply / MathUtils.baseBillion;

        if (billions < 5000) {
            return 0.001 ether;
        } else {
            return 0.0005 ether;
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

    //社区额外补贴率计算
    function getSubsidyRate(uint256 totalSupply) internal pure returns (uint256) {

        uint256 millions = totalSupply / MathUtils.baseMillion;
        
        if (millions < 2) {
            return 900;
        } else if (millions < 10) {
            return 1000 - (millions * 100);
        } else if (millions < 21) {
            return 50;
        } else if (millions < 100) {
            return 25;
        } else {
            return 10;
        }
    }

}
