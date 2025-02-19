// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

error CarbonTrader__NotOwner();

/**
 * 余额管理
 */
contract CarbonTrader {

    /**
     * 每个用户的余额
     */
    mapping (address => uint256) private s_addressToAllowances;

    /**
     * 每个用户冻结的余额
     */
    mapping (address => uint256) private s_frozenAllowances;

    /**
     * 私有 不可更改 主人地址
     */  
    address private immutable i_owner;

    /**
     * 合约部署时调用，将部署者设置为主人
     */  
    constructor() {
        i_owner = msg.sender;
    }

    /**
     * 校验函数，调用者不是i_owner就抛出error
     */
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert CarbonTrader__NotOwner();
        }
        _;
    }

    /**
     * 发放额度，用于给每个用户发放额度
     */
    function issueAllowance(address uesr, uint256 amount) public onlyOwner {
        s_addressToAllowances[uesr] += amount;
    }

    /**
     * 查看自己的额度
     */
    function getAllowance(address uesr) public view returns(uint256) {
        return s_addressToAllowances[uesr];
    }

    /**
     * 冻结额度
     */
    function freezeAllowance(address uesr, uint256 freezedAmount) public onlyOwner {
        require (s_addressToAllowances[uesr] >= freezedAmount, "Freezing amount is less than available.");
        require (freezedAmount >= 0, "Freezing amount is no zreo");
        s_addressToAllowances[uesr] -= freezedAmount;
        s_frozenAllowances[uesr] += freezedAmount;
    }

    /**
     * 解冻额度
     */
    function unFreezeAllowance(address uesr, uint256 unFreezedAmount) public onlyOwner {
        require (s_frozenAllowances[uesr] <= unFreezedAmount, "unFreezing amount is greater than available.");
        require (unFreezedAmount >= 0, "unFreezing amount is no zreo");
        s_addressToAllowances[uesr] += unFreezedAmount;
        s_frozenAllowances[uesr] -= unFreezedAmount;
    }

    /**
     * 查询冻结额度
     */
    function getFrozenAllowance(address uesr) public view returns (uint256) {
        return s_frozenAllowances[uesr];
    }

    /**
     * 销毁某些人的额度
     */
    function destoryAllowance(address uesr, uint256 destoryAmount) public onlyOwner {
        require (destoryAmount >= 0, "unFreezing amount is no zreo");
        s_addressToAllowances[uesr] -= destoryAmount;
    }

    /**
     * 销毁所有额度
     */
    function destoryAllAllowance(address uesr) public onlyOwner {
        s_addressToAllowances[uesr] = 0;
        s_frozenAllowances[uesr] = 0;
    }

}