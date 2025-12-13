// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20Errors} from "./draft-IERC6093.sol";

contract ValidationUtils is IERC20Errors{

    //调用检查
    function _validateHumanCaller() internal view {
        address user = msg.sender;
        if (user != tx.origin) revert NotEOA();
        if (_isContract(user)) revert IsContract();
    }

    //合约检查
    function _isContract(address account) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(account)
        }
        return (size > 0);
    }

    // 地址零检查
    function _validateNotZeroAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    // 零金额检查
    function _validateNotZeroAmount(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    // 正整数检查
    function _validatePositiveAmount(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    // 余额检查
    function _validateSufficientBalance(uint256 balance, uint256 required) internal pure {
        if (balance < required) revert InsufficientBalance();
    }

    // 合约余额检查
    function _validateContractBalance(uint256 balance, uint256 required) internal pure {
        if (balance < required) revert InsufficientContract();
    }

    // 授权检查
    function _validateSufficientAllowance(uint256 allowance, uint256 required) internal pure {
        if (allowance < required) revert InsufficientAllowance();
    }

    // 数组长度检查
    function _validateArrayLength(uint256 length1, uint256 length2) internal pure {
        if (length1 != length2) revert ArrayLengthMismatch();
    }

    // 数组非空检查
    function _validateNonEmptyArray(address[] memory array) internal pure {
        if (array.length == 0) revert EmptyArray();
    }

    // 数值范围检查
    function _validateValueInRange(uint256 value, uint256 min, uint256 max) internal pure {
        if (value < min || value > max) revert ValueOutOfRange();
    }

    // 最小值检查
    function _validateMinValue(uint256 value, uint256 min) internal pure {
        if (value < min) revert ValueTooLow();
    }

    // 最大值检查
    function _validateMaxValue(uint256 value, uint256 max) internal pure {
        if (value > max) revert ValueTooHigh();
    }

    // 布尔条件检查
    function _validateCondition(bool condition) internal pure {
        if (!condition) revert InvalidCondition();
    }

    // 时间戳检查（未来时间）
    function _validateFutureTimestamp(uint256 timestamp) internal view {
        if (timestamp <= block.timestamp) revert InvalidTimestamp();
    }

    // 时间戳检查（过去时间）
    function _validatePastTimestamp(uint256 timestamp) internal view {
        if (timestamp >= block.timestamp) revert InvalidTimestamp();
    }

    // 期限检查（未过期）
    function _validateNotExpired(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert Expired();
    }

}