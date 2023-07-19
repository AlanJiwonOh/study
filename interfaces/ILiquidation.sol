// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ILiquidation {
  function request(bytes32 key) external;
  function execute(bytes32 key,
                   address collateral, uint collateralAmount, 
                   address liquidator, address liquidationToken) external returns (uint amount);
  
  function isLiquidating(bytes32 key) external view returns (bool);
}
