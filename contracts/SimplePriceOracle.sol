// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/IPriceOracle.sol";

contract SimplePriceOracle is IPriceOracle {
    mapping(address => uint) public prices; // Mapping from token to price. Price precision 1e18.
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// ----- ADMIN FUNCTIONS -----
    function setPrice(address _token, uint256 _price) external onlyOwner {
        require(_price != 0, 'setPrice: Invalid input price');
        prices[_token] = _price;
    }

    /// ----- VIEW FUNCTIONS -----
    /// @dev Get token price using oracle.
    /// @param _token Token address to get price.
    function getPrice(address _token) external override view returns (uint256 price) {
        price = prices[_token];
        require(price != 0, 'getPrice: Invalid price');
    }
}
