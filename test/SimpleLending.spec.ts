import {ethers} from 'hardhat';
import hre from 'hardhat';
import {SimpleLending, SimpleLiquidation, SimplePriceOracle, MockERC20} from "../typechain";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {BigNumber} from "ethers";
import {expect} from "chai";

describe('Simple Lending Test', () => {
    let tester: SignerWithAddress;
    let liquidator : SignerWithAddress;
    let lending: SimpleLending;
    let liquidation: SimpleLiquidation;
    let oracle: SimplePriceOracle;
    let token0: MockERC20;
    let token1: MockERC20;

    before('Initial setting', async () => {
        [tester, liquidator] = await ethers.getSigners();
                
        const SimpleLendingFactory = await hre.ethers.getContractFactory('SimpleLending');
        lending = await SimpleLendingFactory.deploy() as SimpleLending;
        
        const SimpleLiquidationFactory = await hre.ethers.getContractFactory('SimpleLiquidation');
        liquidation = await SimpleLiquidationFactory.deploy() as SimpleLiquidation;

        const SimplePriceOracleFactory = await hre.ethers.getContractFactory('SimplePriceOracle');
        oracle = await SimplePriceOracleFactory.deploy() as SimplePriceOracle;

        const MockERC20Factory = await hre.ethers.getContractFactory('MockERC20');
        token0 = await MockERC20Factory.deploy("TEST_TOKEN_0", "T0") as MockERC20;
        token1 = await MockERC20Factory.deploy("TEST_TOKEN_1", "T1") as MockERC20;

        await token0.mint(tester.address, BigNumber.from(10).pow(20));
        await token1.mint(tester.address, BigNumber.from(10).pow(20));

        await token0.mint(liquidator.address, BigNumber.from(10).pow(20));
        await token1.mint(liquidator.address, BigNumber.from(10).pow(20));

        await token0.mint(lending.address, BigNumber.from(10).pow(22));
        await token1.mint(lending.address, BigNumber.from(10).pow(22));

        await lending.setAssetFactor(token0.address, 11000, 9000);
        await lending.setAssetFactor(token1.address, 10500, 9500);

        await lending.setPriceOracle(oracle.address);
        await lending.setLiquidationModule(liquidation.address);
        await liquidation.setPriceOracle(oracle.address);
        
        await oracle.setPrice(token0.address, BigNumber.from(10).pow(18));          
        await oracle.setPrice(token1.address, BigNumber.from(10).pow(18).mul(2));  
    })

    describe('Simple Lending test', () => {
        it("Deposit test", async () => {
            let collateralDepositAmount = BigNumber.from(10).pow(18).mul(2);

            // when
            await token1.approve(lending.address, collateralDepositAmount);
            await lending.deposit(token0.address, token1.address, collateralDepositAmount);

            // then
            let positionKey = await lending.getPositionKey(tester.address, token0.address, token1.address);
            let position = await lending.positions(positionKey);
            await expect(position.collateralAmount).to.equal(collateralDepositAmount);                               
        })

        it("Withdraw test", async () => {
            let collateralWithdrawAmount = BigNumber.from(10).pow(18);

            // when
            await lending.withdraw(token0.address, token1.address, collateralWithdrawAmount);

            // then
            let positionKey = await lending.getPositionKey(tester.address, token0.address, token1.address);
            let position = await lending.positions(positionKey);
            await expect(position.collateralAmount).to.equal(collateralWithdrawAmount);               
        })

        it("Borrow test", async () => {
            let debtBorrowAmount = BigNumber.from(10).pow(18);

            // when
            await lending.borrow(token0.address, token1.address, debtBorrowAmount);

            // then
            let positionKey = await lending.getPositionKey(tester.address, token0.address, token1.address);
            let position = await lending.positions(positionKey);
            await expect(position.debtAmount).to.equal(debtBorrowAmount);                     
        })

        it("Repay test", async () => {
            let debtRepayAmount = BigNumber.from(10).pow(18);

            // when
            await token0.approve(lending.address, debtRepayAmount);
            await lending.repay(token0.address, token1.address, debtRepayAmount.div(2));
            await lending.repay(token0.address, token1.address, debtRepayAmount.div(2));

            // then
            let positionKey = await lending.getPositionKey(tester.address, token0.address, token1.address);
            let position = await lending.positions(positionKey);
            await expect(position.debtAmount).to.equal(0);              
        })

        it("Liquidate Over Auction Time test", async () => {
            let debtBorrowAmount = BigNumber.from(10).pow(18);

            //when
            await lending.borrow(token0.address, token1.address, debtBorrowAmount);

            let positionKey = await lending.getPositionKey(tester.address, token0.address, token1.address);
            let position = await lending.positions(positionKey);

            await oracle.setPrice(token0.address, BigNumber.from(10).pow(18).mul(3));   

            // then
            await lending.liquidateReady(tester.address, token0.address, token1.address);
            
            await hre.network.provider.send("hardhat_mine", ["0x1f40"]);    //over 2 hours

            // token0.approve(liquidator.address, BigNumber.from(10).pow(18))
            // token1.approve(liquidator.address, BigNumber.from(10).pow(18));
            await lending.liquidate(tester.address, token0.address, token1.address, liquidator.address, token0.address);   
        })

        it("Liquidate Within Auction Time test", async () => {
            let collateralDepositAmount = BigNumber.from(10).pow(18).mul(2);
            let debtBorrowAmount = BigNumber.from(10).pow(18);

            // when
            await token1.approve(lending.address, collateralDepositAmount);
            
            await lending.deposit(token0.address, token1.address, collateralDepositAmount);
            await lending.borrow(token0.address, token1.address, debtBorrowAmount);

            let positionKey = await lending.getPositionKey(tester.address, token0.address, token1.address);
            let position = await lending.positions(positionKey);

            await oracle.setPrice(token0.address, BigNumber.from(10).pow(18).mul(4));   

            // then
            await lending.liquidateReady(tester.address, token0.address, token1.address);            
            
            await lending.liquidate(tester.address, token0.address, token1.address, liquidator.address, token0.address);   
        })

        it("Position Reset test", async () => {

        })

        it("Token Transfer test", async () => {

        })
    })
})