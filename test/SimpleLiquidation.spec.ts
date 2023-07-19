import {ethers} from 'hardhat';
import hre from 'hardhat';
import {SimpleLending, SimpleLiquidation, SimplePriceOracle, MockERC20} from "../typechain";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {BigNumber} from "ethers";
import {expect} from "chai";

describe('Simple Liquidation Test', () => {
    let tester: SignerWithAddress;
    let borrower: SignerWithAddress;
    let liquidator: SignerWithAddress;
    let liquidation: SimpleLiquidation;
    let lending: SimpleLending;
    let oracle: SimplePriceOracle;
    let token0: MockERC20;
    let token1: MockERC20;

    before('Initial setting', async () => {
        [tester, borrower, liquidator] = await ethers.getSigners();
        
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

    describe('Simple Liquidation test', () => {
        it("Liquidation State test", async () => {
            // when
            let testerKey = await lending.getPositionKey(tester.address, token0.address, token1.address);
            await liquidation.request(testerKey);

            // then
            await expect(await liquidation.isLiquidating(testerKey)).to.equal(true);

            // when
            let borrowerKey = await lending.getPositionKey(borrower.address, token0.address, token1.address);
            
            // then
            await expect(await liquidation.isLiquidating(borrowerKey)).to.equal(false);
        })
    })
})
