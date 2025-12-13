// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title DepositsManager
 * @dev 存款记录管理合约
 * 负责管理用户VID和USDT共振存款记录
 */
contract DepositsManager {

    // 存款记录结构体
    struct Deposit {
        uint256 time;       //时间
        uint256 amount;     //共振金额
        uint256 mintAmount; //铸造Vollar数量
        bool isVID;         //代币类型：true=VID, false=USDT
    }


    // 用户共振记录结构体
    struct UserDeposits {
        Deposit[20] deposits;   // 记录数组
        uint256 nextIndex;      // 下一个写入索引
        uint256 count;          // 总记录数
    }

    // 共振记录映射
    mapping(address => UserDeposits) internal userDeposits;

    function addDepositRecord(address user, uint256 amount, uint256 backAmount, bool isVIDToken) internal {
        UserDeposits storage d = userDeposits[user];
        uint256 index = d.nextIndex;
        
        d.deposits[index] = Deposit({
            time: block.timestamp,
            amount: amount,
            mintAmount: backAmount,
            isVID: isVIDToken
        });
        
        d.nextIndex = (index + 1) % 20;
        if (d.count < 20) d.count++;
    }


}