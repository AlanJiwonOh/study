// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./libraries/Math.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/ILiquidation.sol";
import "../interfaces/IPriceOracle.sol";

contract SimpleLiquidation is ILiquidation {
    struct Item {
        uint startTime;
        //reserved
    }

    mapping(bytes32 => Item) public liquidations;
    
    IPriceOracle public priceOracle;

    uint private constant INITIAL_DISCOUNT = 500;       //100% = 1e4
    uint private constant MAX_AUCTION_DISCOUNT = 500;   //100% = 1e4
    uint private constant AUCTION_TIME = 2 hours;       //2 hrs = 120 min = 7200 sec
    
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracle);
    }

    /// <---- User Functions ---->  
    function request(bytes32 _key) external {
        require(_key > 0, "Key is zero or negative");
        _initLiquidationItem(_key);
    }

    function execute(bytes32 _key, address _collateral, uint _collateralAmount, address _liquidator, address _liquidationToken) external returns (uint amount){
        require(_key > 0, "Key is zero or negative");
        require(_collateral != address(0), "Collateral doesn't exist");
        require(_collateralAmount > 0, "Collateral amount is zero");
        require(_liquidator != address(0), "Liquidator doesn't exist");
        require(_liquidationToken != address(0), "Liquidator token doesn't exist");
        
        require(_isLiquidating(_key), "Liquidation is not ready, request to start liquidating process");
        
        uint liquidatorCapacity = IERC20(_liquidationToken).balanceOf(_liquidator);
        
        uint liquidationPrice = _getLiquidationPrice(_key, _collateral);
        uint liquidationValue = liquidationPrice * _collateralAmount;        
        uint liquidationAmount = liquidationValue / priceOracle.getPrice(_liquidationToken);

        require((liquidationAmount <= liquidatorCapacity), "Not enough liquidator balance to participate in the liquidation");
        
        _resetLiquidationItem(_key);

        //delegate token transfer and position clear to lending
        return liquidationAmount;
    }

    function isLiquidating(bytes32 _key) external view returns (bool){
        return _isLiquidating(_key);
    }

    function _isLiquidating(bytes32 _key) private view returns (bool){ 
        if(liquidations[_key].startTime > 0) {
            return true;
        } 
        return false;
    }

    function _initLiquidationItem(bytes32 _key) private { 
        liquidations[_key].startTime = block.timestamp;
    }

    function _resetLiquidationItem(bytes32 _key) private { 
        liquidations[_key].startTime = 0;
    }

    function _getLiquidationPrice(bytes32 _key, address _collateral) private view returns (uint){
        uint collateralPrice = priceOracle.getPrice(_collateral);
        uint initialDiscountRatioNumerator = 1e4 - INITIAL_DISCOUNT;
        uint initialDiscountPrice = Math.mulDiv(
            collateralPrice,
            initialDiscountRatioNumerator,
            1e4    
        ); 

        uint auctionDiscountRatioNumerator = 0;
        uint elapsedTime = block.timestamp - liquidations[_key].startTime;
        if(elapsedTime < AUCTION_TIME) {
            uint auctionDiscount = Math.mulDiv(
                elapsedTime,
                MAX_AUCTION_DISCOUNT,
                AUCTION_TIME
            );
            auctionDiscountRatioNumerator = 1e4 - auctionDiscount; 
        } else {
            auctionDiscountRatioNumerator = 1e4 - MAX_AUCTION_DISCOUNT;
        }
        
        uint liquidationPrice = Math.mulDiv(
            initialDiscountPrice,
            auctionDiscountRatioNumerator,
            1e4
        );

        return liquidationPrice;
    }
}

