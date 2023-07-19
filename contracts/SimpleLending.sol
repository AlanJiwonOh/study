// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./libraries/Math.sol";

import "../interfaces/IERC20.sol";
import "../interfaces/ILending.sol";
import "../interfaces/IPriceOracle.sol";
import "./SimpleLiquidation.sol";


/// @title Simple Lending
contract SimpleLending is ILending {
    struct Position {
        uint debtAmount;
        uint collateralAmount;
    }

    struct Asset {
        uint debtFactor; // 100% =  1e4
        uint collateralFactor; // 100% = 1e4
    }

    mapping(address => Asset) public assets;
    mapping(bytes32 => Position) public positions;
    IPriceOracle public priceOracle;
    ILiquidation public liquidationModule;
    
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setAssetFactor(address _asset, uint _debtFactor, uint _collateralFactor) external onlyOwner {
        assets[_asset].debtFactor = _debtFactor;
        assets[_asset].collateralFactor = _collateralFactor;
    }

    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracle);
    }

    function setLiquidationModule(address _liquidationModule) external onlyOwner {
        liquidationModule = ILiquidation(_liquidationModule);
    }

    /// <---- User Functions ---->
    function deposit(address _debt, address _collateral, uint _collateralDelta) external {
        // 0. Copy position
        bytes32 positionKey = getPositionKey(msg.sender, _debt, _collateral);
        Position memory position = positions[positionKey];

        // 1. Increase collateral amount
        position.collateralAmount += _collateralDelta;

        // 2. Transfer collateral from sender
        IERC20(_collateral).transferFrom(msg.sender, address(this), _collateralDelta);

        // 3. Store position changes
        positions[positionKey] = position;
    }

    function withdraw(address _debt, address _collateral, uint _collateralDelta) external {
        // 0. Copy position
        bytes32 positionKey = getPositionKey(msg.sender, _debt, _collateral);
        Position memory position = positions[positionKey];

        // 1. Decrease collateral amount & health check
        position.collateralAmount -= _collateralDelta;
        require(_healthCheck(position, _debt, _collateral), "Unhealthy position");

        // 2. Transfer collateral from sender
        IERC20(_collateral).transfer(msg.sender, _collateralDelta);

        // 3. Store position changes
        positions[positionKey] = position;
    }

    function borrow(address _debt, address _collateral, uint _debtDelta) external {
        // 0. Copy position
        bytes32 positionKey = getPositionKey(msg.sender, _debt, _collateral);
        Position memory position = positions[positionKey];

        // 1. Increase collateral amount & health check
        position.debtAmount += _debtDelta;
        require(_healthCheck(position, _debt, _collateral), "Unhealthy position");

        // 2. Transfer collateral from sender
        IERC20(_debt).transfer(msg.sender, _debtDelta);

        // 3. Store position changes
        positions[positionKey] = position;
    }

    function repay(address _debt, address _collateral, uint _debtDelta) external {
        // 0. Copy position
        bytes32 positionKey = getPositionKey(msg.sender, _debt, _collateral);
        Position memory position = positions[positionKey];

        // 1. Decrease collateral amount
        position.debtAmount -= _debtDelta;

        // 2. Transfer collateral from sender
        IERC20(_debt).transferFrom(msg.sender, address(this), _debtDelta);

        // 3. Store position changes
        positions[positionKey] = position;
    }

    function liquidateReady(address _user, address _debt, address _collateral) external {
        bytes32 positionKey = getPositionKey(_user, _debt, _collateral);

        require(!_healthCheck(positions[positionKey], _debt, _collateral), "Over-collateralization");
        require(!liquidationModule.isLiquidating(positionKey), "The liquidation item is already registered");

        liquidationModule.request(positionKey);        
    }

    function liquidate(address _user, address _debt, address _collateral, address _liquidator, address _token) external {
        bytes32 positionKey = getPositionKey(_user, _debt, _collateral);
        require(liquidationModule.isLiquidating(positionKey), "Liqudation is not ready");
        
        Position memory position = positions[positionKey];
        uint liquidationAmount = liquidationModule.execute(positionKey, _collateral, position.collateralAmount, _liquidator, _token);
        require(liquidationAmount > 0, "No free lunch");

        /// <---- Disposal ---->
        {
            //acquisition: from lending to liquidiator
            IERC20(_collateral).transfer(_liquidator, position.collateralAmount);  
            
            //repayment: from liquidator to lending
            //fixme: approve to get allowance
            // IERC20(_token).transferFrom(_liquidator, address(this), liquidationAmount);  
            IERC20(_token).transferFrom(_liquidator, address(this), 0);      
        }
        
        _resetPosition(positionKey);
    }

    function healthCheck(address _user, address _debt, address _collateral) external view returns (bool){
        bytes32 positionKey = getPositionKey(_user, _debt, _collateral);
        return _healthCheck(positions[positionKey], _debt, _collateral);
    }

    function _healthCheck(
        Position memory _position,
        address _debt,
        address _collateral
    ) internal view returns (bool){
        uint debtValue = Math.mulDiv(
            priceOracle.getPrice(_debt),
            _position.debtAmount,
            1e18
        ); 
        uint debtCredit = Math.mulDiv(
            debtValue,
            assets[_debt].debtFactor,
            1e4
        ); 
        uint collateralValue = Math.mulDiv(
            priceOracle.getPrice(_collateral),
            _position.collateralAmount,
            1e18
        );
        uint collateralCredit = Math.mulDiv(
            collateralValue,
            assets[_collateral].collateralFactor,
            1e4
        );
        return debtCredit < collateralCredit;
    }

    function _resetPosition(bytes32 _key) private {
        Position memory position = positions[_key];
        position.debtAmount = 0;
        position.collateralAmount = 0;

        positions[_key] = position;
    }

    function getPositionKey(address _user, address _debt, address _collateral) public pure returns (bytes32){
        return keccak256(abi.encode(_user, _debt, _collateral));
    }

    
}
