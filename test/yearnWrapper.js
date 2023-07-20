/* global ethers */

const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const WETH_ABI = require("./abi/WETH.json")
const OP_ABI = require("./abi/OP.json")
const YVUSDC_ABI = require("./abi/YVUSDC.json")
const YVETH_ABI = require("./abi/YVETH.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const WETH_Addr = "0x4200000000000000000000000000000000000006"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const YVUSDC_Addr = "0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2"
const YVETH_Addr = "0x5B977577Eb8a480f63e11FC615D6753adB8652Ae"
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const StakingRewards_YVUSDC_Addr = "0xB2c04C55979B6CA7EB10e666933DE5ED84E6876b"
const StakingRewards_YVETH_Addr = "0xE35Fec3895Dcecc7d2a91e8ae4fF3c0d43ebfFE0"

/* Swap Params */

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "200" // 2%
const wait = "12" // 12 seconds
const poolFee = "3000" // 0.3%

describe("Test Yearn custom wrappers", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]

        const signer = (await ethers.provider.getSigner(0))

        console.log(await helpers.time.latestBlock())

        const WYVUSDC = await ethers.getContractFactory("YearnZapReinvestWrapper")
        const wyvUSDC = await WYVUSDC.deploy(
            YVUSDC_Addr,
            YVOP_Addr,
            StakingRewards_YVUSDC_Addr,
            "0x0000000000000000000000000000000000000000",
            USDC_Addr,
            getRewardMin,
            amountInMin,
            slippage,
            wait,
            poolFee,
            {gasLimit: "30000000"}
        )
        await wyvUSDC.waitForDeployment()
        console.log("wyvUSDC deployed: ", await wyvUSDC.getAddress())
    
        const WYVETH = await ethers.getContractFactory("YearnZapReinvestWrapper")
        const wyvETH = await WYVETH.deploy(
            YVETH_Addr,
            YVOP_Addr,
            StakingRewards_YVETH_Addr,
            "0x13e3Ee699D1909E989722E753853AE30b17e08c5", // ETH price feed
            WETH_Addr,
            getRewardMin,
            amountInMin,
            slippage,
            wait,
            poolFee,
            {gasLimit: "30000000"}
        )
        await wyvETH.waitForDeployment()
        console.log("wyvETH deployed: ", await wyvETH.getAddress())

        /* Initial deposit */
        const whaleUsdcEth = await ethers.getImpersonatedSigner("0xee55c2100C3828875E0D65194311B8eF0372C6d9")
        const _usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(whaleUsdcEth)
        await _usdc.transfer(await owner.getAddress(), "1000000000") // 1,000 USDC
        console.log("Transferred USDC")
        const _weth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(whaleUsdcEth)
        await _weth.transfer(await owner.getAddress(), "500000000000000000") // 0.5 wETH
        console.log("Transferred ETH")
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        await usdc.approve(await wyvUSDC.getAddress(), "1000000000")
        console.log("Approved wrapper USDC spend")
        await wyvUSDC.deposit("1000000000", await owner.getAddress())
        console.log("Deposited USDC to wrapper")
        const weth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(signer)
        await weth.approve(await wyvETH.getAddress(), "500000000000000000")
        console.log("Approved wrapper WETH spend")
        await wyvETH.deposit("500000000000000000", await owner.getAddress())
        console.log("Deposited WETH to wrapper")

        // yvUSDC contract
        const yvUSDC = (await ethers.getContractAt(
            YVUSDC_ABI,
            YVUSDC_Addr
        )).connect(signer);

        // yvETH contract
        const yvETH = (await ethers.getContractAt(
            YVETH_ABI,
            YVETH_Addr
        )).connect(signer)

        const t0_wyvUSDCBal = await wyvUSDC.balanceOf(await owner.getAddress())
        // Preview how much yvUSDC Owner should redeem
        const t0_yvUSDCBal = await wyvUSDC.previewRedeem(t0_wyvUSDCBal.toString())
        const t0_wyvETHBal = await wyvETH.balanceOf(await owner.getAddress())
        // Preview how much yvETH Owner should redeem
        const t0_yvETHBal = await wyvETH.previewRedeem(t0_wyvETHBal.toString())

        // Starting balance
        console.log("t0 Owner wyvUSDC bal: " + t0_wyvUSDCBal.toString())
        // Note yvUSDC and yvETH are sitting in respective StakingRewards contract
        console.log("t0 Owner yvUSDC bal: " + t0_yvUSDCBal.toString())
        console.log("t0 Owner wyvETH bal: " + t0_wyvETHBal.toString())
        console.log("t0 Owner yvETH bal: " + t0_yvETHBal.toString())

        // Set up executable harvest by transferring OP to wrappers
        const whaleOp = await ethers.getImpersonatedSigner("0x82326a9E6BD66e51a4c2c29168B10A1853Fc9Af7")
        const _op = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(whaleOp)
        await _op.transfer(await wyvUSDC.getAddress(), "1010000000000000000") // 1.01 OP
        await _op.transfer(await wyvETH.getAddress(), "1010000000000000000") // 1.01 OP

        return {
            owner, signer, wyvUSDC, wyvETH, usdc, weth, _usdc, _weth, yvUSDC, yvETH
        }
    }

    it("Should swap reward for want and reinvest", async function() {

        const { owner, wyvUSDC, wyvETH, usdc, weth } = await loadFixture(deploy)

        /* Harvest */
        await wyvUSDC.harvest()
        await wyvETH.harvest()

        const t1_wyvUSDCBal = await wyvUSDC.balanceOf(await owner.getAddress())
        // Preview how much yvUSDC Owner should redeem
        const t1_yvUSDCBal = await wyvUSDC.previewRedeem(t1_wyvUSDCBal.toString())
        const t1_wyvETHBal = await wyvETH.balanceOf(await owner.getAddress())
        // Preview how much yvUSDC Owner should redeem
        const t1_yvETHBal = await wyvETH.previewRedeem(t1_wyvETHBal.toString())
        
        // Post-harvest balance
        console.log("t1 Owner wyvUSDC bal: " + t1_wyvUSDCBal.toString())
        console.log("t1 Owner yvUSDC bal: " + t1_yvUSDCBal.toString())
        console.log("t1 Owner wyvETH bal: " + t1_wyvETHBal.toString())
        console.log("t1 Owner yvETH bal: " + t1_yvETHBal.toString())

        /* Redemption */
        await wyvUSDC.redeem(t1_wyvUSDCBal.toString(), owner.getAddress(), owner.getAddress())
        await wyvETH.redeem(t1_wyvETHBal.toString(), owner.getAddress(), owner.getAddress())

        const t2_wyvUSDCBal = await wyvUSDC.balanceOf(owner.getAddress())
        const t2_wyvETHBal = await wyvETH.balanceOf(owner.getAddress())
        const t2_USDCBal = await usdc.balanceOf(owner.getAddress())
        const t2_wETHBal = await weth.balanceOf(owner.getAddress())

        console.log("t2 Owner wyvUSDC bal: " + t2_wyvUSDCBal.toString())
        console.log("t2 Owner wyvETH bal: " + t2_wyvETHBal.toString())
        console.log("t2 Owner USDC bal: " + t2_USDCBal.toString())
        console.log("t2 Owner wETH bal: " + t2_wETHBal.toString())
    })

    it("Should allow for manual reinvesting", async function() {

        const { owner, wyvUSDC, wyvETH, usdc, weth, _usdc, _weth } = await loadFixture(deploy)

        // Get reward from wrapper
        await wyvUSDC.recoverERC20(OP_Addr, "1")
        console.log("Claimed rewards")

        // Simulate manual swap by transferring assets to respective wrapper contract
        _usdc.transfer(wyvUSDC.getAddress(), "100000000") // 100 USDC
        _weth.transfer(wyvETH.getAddress(), "50000000000000000") // 0.05 wETH

        // Set swap-enabled to 0 to do harvest without swap operation
        await wyvUSDC.setEnabled("0")
        await wyvETH.setEnabled("0")

        /* Harvest */
        await wyvUSDC.harvest()
        await wyvETH.harvest()

        const t1_wyvUSDCBal = await wyvUSDC.balanceOf(await owner.getAddress())
        // Preview how much yvUSDC Owner should redeem
        const t1_yvUSDCBal = await wyvUSDC.previewRedeem(t1_wyvUSDCBal.toString())
        const t1_wyvETHBal = await wyvETH.balanceOf(await owner.getAddress())
        // Preview how much yvUSDC Owner should redeem
        const t1_yvETHBal = await wyvETH.previewRedeem(t1_wyvETHBal.toString())

        // Post-harvest balance
        console.log("t1 Owner wyvUSDC bal: " + t1_wyvUSDCBal.toString())
        console.log("t1 Owner yvUSDC bal: " + t1_yvUSDCBal.toString())
        console.log("t1 Owner wyvETH bal: " + t1_wyvETHBal.toString())
        console.log("t1 Owner yvETH bal: " + t1_yvETHBal.toString())

        /* Redemption */
        await wyvUSDC.redeem(t1_wyvUSDCBal.toString(), owner.getAddress(), owner.getAddress())
        await wyvETH.redeem(t1_wyvETHBal.toString(), owner.getAddress(), owner.getAddress())

        const t2_wyvUSDCBal = await wyvUSDC.balanceOf(owner.getAddress())
        const t2_wyvETHBal = await wyvETH.balanceOf(owner.getAddress())
        const t2_USDCBal = await usdc.balanceOf(owner.getAddress())
        const t2_wETHBal = await weth.balanceOf(owner.getAddress())

        console.log("t2 Owner wyvUSDC bal: " + t2_wyvUSDCBal.toString())
        console.log("t2 Owner wyvETH bal: " + t2_wyvETHBal.toString())
        console.log("t2 Owner USDC bal: " + t2_USDCBal.toString())
        console.log("t2 Owner wETH bal: " + t2_wETHBal.toString())
    })
})