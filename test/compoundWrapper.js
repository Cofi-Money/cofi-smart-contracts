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
            (await owner.getAddress())
        )

        // Initial deposit
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

        return {
            owner, signer, wsoBTC, sowBTC, wbtc
        }
    }

    it("Should deposit", async function() {

        const { owner, signer, wsoBTC, sowBTC, wbtc } = await loadFixture(deploy)

        const t0_wsoBTCBal = await wsoBTC.balanceOf(await owner.getAddress())
        // Preview how much wBTC Owner should redeem
        const t0_wbtcBal = await wsoBTC.previewRedeem(t0_wsoBTCBal.toString())
        
        // Starting balance
        console.log("t0 Owner wsoBTC bal: " + t0_wsoBTCBal.toString())
        console.log("t0 Owner wBTC bal: " + t0_wbtcBal.toString())

        // Set up executable harvest
        const whaleOp = await ethers.getImpersonatedSigner("0x82326a9E6BD66e51a4c2c29168B10A1853Fc9Af7")
        const _op = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(whaleOp)
        await _op.transfer(await wsoBTC.getAddress(), "10000000000000000000000") // 10,000 OP
        console.log("Transferred OP to wrapper")

        await wsoBTC.setRoute("3000", WETH_Addr, "3000")
        console.log("Set route")

        // Harvest
        await wsoBTC.harvest("0")

        // wsoBTC balance is unchanged
        const t1_wsoBTCBal = await wsoBTC.balanceOf(await owner.getAddress())
        // Preview how much wBTC Owner should redeem
        const t1_wbtcBal = await wsoBTC.previewRedeem(t1_wsoBTCBal.toString())
        
        // Post-harvest balance
        console.log("t1 Owner wsoBTC bal: " + t1_wsoBTCBal.toString())
        console.log("t1 Owner wBTC bal: " + t1_wbtcBal.toString())

        await wsoBTC.redeem(t1_wsoBTCBal.toString(), owner.getAddress(), owner.getAddress())

        const t2_wbtcBal = await wbtc.balanceOf(owner.getAddress())
        console.log("t2 Owner wBTC bal: " + t2_wbtcBal.toString())
    })
})