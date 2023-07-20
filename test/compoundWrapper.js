/* global ethers */

const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const WBTC_ABI = require("./abi/WBTC.json")
const SOWBTC_ABI = require("./abi/SOWBTC.json")
const OP_ABI = require("./abi/OP.json")

const WBTC_Addr = "0x68f180fcCe6836688e9084f035309E29Bf0A2095"
const SOWBTC_Addr = "0x33865E09A572d4F1CC4d75Afc9ABcc5D3d4d867D"
const WETH_Addr = "0x4200000000000000000000000000000000000006"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const COMPTROLLER_Addr = "0x60cf091cd3f50420d50fd7f707414d0df4751c58"

describe("Test Compound custom wrapper", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]

        const signer = (await ethers.provider.getSigner(0))

        console.log(await helpers.time.latestBlock())

        const WSOBTC = await ethers.getContractFactory("CompoundV2ERC4626Wrapper")
        const wsoBTC = await WSOBTC.deploy(
            WBTC_Addr,
            OP_Addr,
            SOWBTC_Addr,
            COMPTROLLER_Addr,
            "0xd702dd976fb76fffc2d3963d037dfdae5b04e593", // BTC price feed
            (await owner.getAddress()),
            "1000000000000000000", // amountInMin = 1 OP
            "200", // slippage = 2%
            "12" // wait = 12 seconds
        )

        /* Initial deposit */
        const whaleBtc = await ethers.getImpersonatedSigner("0x456325F2AC7067234dD71E01bebe032B0255e039")
        const _wbtc = (await ethers.getContractAt(WBTC_ABI, WBTC_Addr)).connect(whaleBtc)
        await _wbtc.transfer(await owner.getAddress(), "50000000") // 0.5 wBTC
        console.log("Transferred wBTC")
        const wbtc = (await ethers.getContractAt(WBTC_ABI, WBTC_Addr)).connect(signer)
        await wbtc.approve(await wsoBTC.getAddress(), "50000000")
        console.log("Approved wrapper spend")
        await wsoBTC.deposit("50000000", await owner.getAddress())

        // soWBTC contract
        const sowBTC = (await ethers.getContractAt(SOWBTC_ABI, SOWBTC_Addr)).connect(signer)

        const t0_wsoBTCBal = await wsoBTC.balanceOf(await owner.getAddress())
        // Preview how much wBTC Owner should redeem
        const t0_wbtcBal = await wsoBTC.previewRedeem(t0_wsoBTCBal.toString())
        
        // Starting balance
        console.log("t0 Owner wsoBTC bal: " + t0_wsoBTCBal.toString())
        console.log("t0 Owner wBTC bal: " + t0_wbtcBal.toString())

        // Set up executable harvest
        const whaleOp = await ethers.getImpersonatedSigner("0x82326a9E6BD66e51a4c2c29168B10A1853Fc9Af7")
        const _op = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(whaleOp)
        await _op.transfer(await wsoBTC.getAddress(), "100000000000000000000") // 100 OP
        console.log("Transferred OP to wrapper")

        // Set swap route
        await wsoBTC.setRoute("3000", WETH_Addr, "3000")
        console.log("Set route")

        return {
            owner, signer, wsoBTC, sowBTC, wbtc, _op, _wbtc
        }
    }

    it("Should harvest with swap and redeem", async function() {

        // wsoBTC => sowBTC => wBTC
        const { owner, wsoBTC, sowBTC, wbtc } = await loadFixture(deploy)

        /* Harvest */
        await wsoBTC.harvest()

        // wsoBTC balance is unchanged
        const t1_wsoBTCBal = await wsoBTC.balanceOf(await owner.getAddress())
        // Preview how much wBTC Owner should redeem
        const t1_wbtcBal = await wsoBTC.previewRedeem(t1_wsoBTCBal.toString())
        
        // Post-harvest balance
        console.log("t1 Owner wsoBTC bal: " + t1_wsoBTCBal.toString())
        console.log("t1 Owner wBTC bal: " + t1_wbtcBal.toString())

        await wsoBTC.redeem("25000000", owner.getAddress(), owner.getAddress())

        const t2_wbtcBal = await wbtc.balanceOf(owner.getAddress())
        console.log("t2 Owner wBTC bal: " + t2_wbtcBal.toString())
    })

    it("Should harvest with swap disabled and redeem", async function() {

        // wsoBTC => sowBTC => wBTC
        const { owner, wsoBTC, sowBTC, wbtc, _wbtc } = await loadFixture(deploy)

        // Disable swap route
        await wsoBTC.setEnabled("0")
    
        _wbtc.transfer(wsoBTC.getAddress(), "10000000") // 0.1 wBTC
        const t1_wrapperWbtcBal = await wbtc.balanceOf(wsoBTC.getAddress())
        console.log("t1 Wrapper wBTC bal: " + t1_wrapperWbtcBal.toString())
        // For some reason this contract instance only shows the bal increase
        // despite both instances referring to the same contract.
        const t1_wrapperWbtcBal_ = await _wbtc.balanceOf(wsoBTC.getAddress())
        console.log("t1 Wrapper wBTC bal: " + t1_wrapperWbtcBal_.toString())

        /* Harvest */
        await wsoBTC.harvest()
        const t2_wrapperWbtcBal = await wbtc.balanceOf(wsoBTC.getAddress())
        console.log("t2 Wrapper wBTC bal: " + t2_wrapperWbtcBal.toString())

        // wsoBTC balance is unchanged
        const t2_wsoBTCBal = await wsoBTC.balanceOf(await owner.getAddress())
        // Preview how much wBTC Owner should redeem
        const t2_wbtcBal = await wsoBTC.previewRedeem(t2_wsoBTCBal.toString())
        
        // Post-harvest balance
        console.log("t2 Owner wsoBTC bal: " + t2_wsoBTCBal.toString())
        console.log("t2 Owner wBTC bal: " + t2_wbtcBal.toString())

        await wsoBTC.redeem("25000000", owner.getAddress(), owner.getAddress())

        const t3_wbtcBal = await wbtc.balanceOf(owner.getAddress())
        console.log("t3 Owner wBTC bal: " + t3_wbtcBal.toString())
    })
})