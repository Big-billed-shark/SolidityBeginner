// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error CarbonTrader__NotOwner();
error CarbonTrader__ParamError();
error CarbonTrader__TransferFailed();

/**
 * 余额管理
 */
contract CarbonTrader {

    /**
     * 每个买家的钱
     */
    mapping (address => uint256) private s_auctionAmount;

    /**
     * 每个用户的余额
     */
    mapping (address => uint256) private s_addressToAllowances;

    /**
     * 每个用户冻结的余额
     */
    mapping (address => uint256) private s_frozenAllowances;

    struct trade {
        address seller;             // 卖家地址
        uint256 sellAmount;         // 要拍卖的额度
        uint256 startTimestamp;     // 拍卖开始时间戳
        uint256 endTimestamp;       // 拍卖结束时间戳
        uint256 minimumBidAmount;   // 最小起拍数量
        uint256 initPriceOfUnit;    // 每单位的起拍价格
        mapping(address => uint256) deposits; // 每个买家的押金
        mapping(address => string) bidinfos; // 买家投标加密信息;
        mapping(address => string) bidSecrets; // 买家密钥;
    }

    /**
     * 所有的交易
     */
    mapping(string => trade) private s_trade;

    /**
     * 私有 不可更改 主人地址
     */  
    address private immutable i_owner;

    /**
     * 私有 不可更改 质押合约
     */  
    IERC20 private immutable i_usdtToken;

    /**
     * 合约部署时调用，将部署者设置为主人
     */  
    constructor(address usdtTokenAddress) {
        i_owner = msg.sender;
        i_usdtToken = IERC20(usdtTokenAddress);
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

    /**
     * 发起交易
     */
    function startTrade (
        string memory tradeId,
        uint256 amount,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 minimumBidAmount,
        uint256 initPriceOfUnit
    ) public {
        if (
            amount <= 0 || startTimestamp >= endTimestamp ||
            minimumBidAmount <= 0 || initPriceOfUnit <= 0 ||
            minimumBidAmount > amount
        ) revert CarbonTrader__ParamError();

        trade storage newTrade = s_trade[tradeId];
        newTrade.seller = msg.sender;
        newTrade.sellAmount = amount;
        newTrade.startTimestamp = startTimestamp;
        newTrade.endTimestamp = endTimestamp;
        newTrade.minimumBidAmount = minimumBidAmount;
        newTrade.initPriceOfUnit = initPriceOfUnit;
        // 冻结金额
        freezeAllowance(msg.sender, amount);
    }

    /**
     * 获得交易信息
     */
    function getTrade(string memory tradeId) public view returns(address, uint256, uint256, uint256, uint256, uint256) {
        trade storage curTrade = s_trade[tradeId];
        return (
            curTrade.seller,
            curTrade.sellAmount,
            curTrade.startTimestamp,
            curTrade.endTimestamp,
            curTrade.minimumBidAmount,
            curTrade.initPriceOfUnit
        );
    }

    /**
     * 支付押金
     */
    function deposit(string memory tradeId, uint256 amount, string memory info) public {
        trade storage curTrade = s_trade[tradeId];

        bool success = i_usdtToken.transferFrom(msg.sender, address(this), amount);

        if (!success) revert CarbonTrader__TransferFailed();

        curTrade.deposits[msg.sender] = amount;

        // 设置信息
        setBidInfo(tradeId, info); 
    }

    /**
     * 押金退还
     */
    function refundDeposit(string memory tradeId) public {
        trade storage curTrade = s_trade[tradeId];
        uint256 depositAmount = curTrade.deposits[msg.sender];
        curTrade.deposits[msg.sender] = 0;

        bool success = i_usdtToken.transfer(msg.sender, depositAmount);

        if (!success) {
            curTrade.deposits[msg.sender] = depositAmount;
            revert CarbonTrader__TransferFailed();
        }
    }

    /**
     * 设置交易信息
     */
    function setBidInfo(string memory tradeId, string memory info) public {
        trade storage curTrade = s_trade[tradeId];
        curTrade.bidinfos[msg.sender] = info;
    }

    /**
     * 设置用户密钥
     */
    function setBidSecret(string memory tradeId, string memory secret) public {
        trade storage curTrade = s_trade[tradeId];
        curTrade.bidSecrets[msg.sender] = secret;
    }

    /**
     * 获取用户的交易信息
     */
    function getBidInfo(string memory tradeId) public view returns(string memory) {
        trade storage curTrade = s_trade[tradeId];
        return curTrade.bidinfos[msg.sender];
    }

    /**
     * 结算
     */    
    function finalizeAuctionAndTransferCarbon(
        string memory tradeId,
        uint256 allowanceAmount,
        uint256 addtionalAmountToPay
    ) public {
        // 获取保证金
        uint256 depositAmount = s_trade[tradeId].deposits[msg.sender];
        s_trade[tradeId].deposits[msg.sender] = 0;

        // 把保证金和新补的这些钱给卖家
        address seller = s_trade[tradeId].seller;
        s_auctionAmount[seller] += (depositAmount + addtionalAmountToPay);

        // 扣除卖家的额度
        s_frozenAllowances[seller] = 0;

        // 增加买家的额度
        s_addressToAllowances[msg.sender] += allowanceAmount;

        bool success = i_usdtToken.transferFrom(msg.sender, address(this), addtionalAmountToPay);
        if (!success) revert CarbonTrader__TransferFailed();
    }


    /**
     * 卖家提现
     */  
    function withdrawAcutionAmount() public {
        uint256 auctionAmount = s_auctionAmount[msg.sender];
        s_auctionAmount[msg.sender] = 0;

        bool success = i_usdtToken.transfer(msg.sender, auctionAmount);

        if (!success) {
            s_auctionAmount[msg.sender] = auctionAmount;
            revert CarbonTrader__TransferFailed();
        }
    }

}