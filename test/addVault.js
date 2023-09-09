/* global ethers */

const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

const COFIMoney_Addr = "0x3c9F3b896EC6cC7AF79f5d1E127FD1e84940da4e"
const YVUSDT_Addr = "0xFaee21D0f0Af88EE72BB6d68E54a90E6EC2616de"
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const USDT_Addr = "0x94b008aA00579c1307B0EF2c499aD98a8ce58e58"
const StakingRewards_YVUSDT_Addr = "0xf66932f225cA48856B7f97b6F060f4c0D244Af8E"
const USDTPriceFeed_Addr = "0xecef79e109e997bca29c1c0897ec9d7b03647f5e"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const COUSD_Addr = "0x8924ad39beEB4f8B778A1CcA6CB7CE89788eA895"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

const USDT_ABI = require("./abi/USDT.json")
const OP_ABI = require("./abi/OP.json")

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "1500" // 15%
const wait = "12" // 12 seconds
const poolFee = "3000" // 0.3%

/* Optimism */

describe("Test adding vault with new underlying", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const signer = await ethers.provider.getSigner(0)

        console.log(await helpers.time.latestBlock())

        const cofiMoney = (await ethers.getContractAt(
            "COFIMoney",
            COFIMoney_Addr
        )).connect(signer)

        // Set swap route (already set).
        // Set swap protocol (already set).

        // // Set decimals
        // await cofiMoney.setDecimals(USDT_Addr, "6")
        // console.log("Decimals set")

        // // Set price feed
        // await cofiMoney.setPriceFeed(USDT_Addr, USDTPriceFeed_Addr)

        // // Set buffer
        // await cofiMoney.setBuffer(USDT_Addr, "10000000") // 10 USDT buffer

        // // Transfer buffer.
        // const usdt = (await ethers.getContractAt(
        //     USDT_ABI,
        //     USDT_Addr
        // )).connect(signer)
        // await usdt.transfer(COFIMoney_Addr, "10000000")

        // Deploy vault
        const WYVUSDT = await ethers.getContractFactory("YearnV2StakingRewards")
        const wyvUSDT = await WYVUSDT.deploy(
            YVUSDT_Addr,
            YVOP_Addr,
            StakingRewards_YVUSDT_Addr,
            USDTPriceFeed_Addr,
            getRewardMin,
            amountInMin,
            slippage,
            wait,
            poolFee,
            "1"
        )
        await wyvUSDT.waitForDeployment()
        console.log("wyvUSDT deployed: ", await wyvUSDT.getAddress())

        // Set migration enabled
        await cofiMoney.setMigrationEnabled(
            await cofiMoney.getVault(COUSD_Addr),
            await wyvUSDT.getAddress(),
            "1"
        )

        // Set up executable harvest
        const op = (await ethers.getContractAt(
            OP_ABI,
            OP_Addr
        )).connect(signer)
        await op.transfer(await wyvUSDT.getAddress(), ethers.parseEther('2'))

        // Set harvestable.

        const cousd = (await ethers.getContractAt(
            "COFIRebasingToken",
            COUSD_Addr
        )).connect(signer)

        console.log("Owner coUSD bal: ", await cousd.balanceOf(await owner.getAddress()))

        return { cofiMoney, wyvUSDT, usdt, cousd, owner }
    }

    it("Should deposit, rebase, and withdraw", async function() {

        const { cofiMoney, wyvUSDT, usdt, owner, cousd } = await loadFixture(deploy)

        await cofiMoney.migrate(COUSD_Addr, await wyvUSDT.getAddress())
        console.log("Migration executed")

        console.log("t1 Owner coUSD bal: ", await cousd.balanceOf(await owner.getAddress()))

        await usdt.approve(COFIMoney_Addr, await usdt.balanceOf(await owner.getAddress()))

        console.log("Estimated coUSD out: ", await cofiMoney.getEstimatedCofiOut(
            "20000000",
            USDT_Addr,
            COUSD_Addr
        ))

        await cofiMoney.enterCofi(
            "20000000", // 20 USDT
            USDT_Addr,
            COUSD_Addr,
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )

        console.log("t2 Owner coUSD bal: ", await cousd.balanceOf(await owner.getAddress()))

        await cousd.approve(COFIMoney_Addr, await cousd.balanceOf(await owner.getAddress()))

        await cofiMoney.exitCofi(
            await cousd.balanceOf(await owner.getAddress()),
            USDT_Addr,
            COUSD_Addr,
            await owner.getAddress(),
            await owner.getAddress()
        )

        console.log("t3 Owner USDT bal: ", await usdt.balanceOf(await owner.getAddress()))
    })
})