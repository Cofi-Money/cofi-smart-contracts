/* global ethers */

const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const DAI_ABI = require("./abi/DAI_Optimism.json")
const WETH_ABI = require("./abi/WETH.json")
const WBTC_ABI = require("./abi/WBTC.json")
const OP_ABI = require("./abi/OP.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const DAI_Addr = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"
const WETH_Addr = "0x4200000000000000000000000000000000000006"
const WBTC_Addr = "0x68f180fcCe6836688e9084f035309E29Bf0A2095"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const USDCWhale_Addr = "0x16224283bE3f7C0245d9D259Ea82eaD7fcB8343d"
const WETHWhale_Addr = "0x0Eb21ed8543789C79bEd81D85b13eA31E7aC805b"
const DAIWhale_Addr = "0xb3Bdb50f1DF8F7AA756a26af398f034FE18F064A"
const WBTCWhale_Addr = "0x456325F2AC7067234dD71E01bebe032B0255e039"
const OPWhale_Addr = "0x82326a9E6BD66e51a4c2c29168B10A1853Fc9Af7"
const USDCPriceFeed_Addr = "0x16a9fa2fda030272ce99b29cf780dfa30361e0f3"
const DAIPriceFeed_Addr = "0x8dba75e83da73cc766a7e5a0ee71f656bab470d6"
const WBTCPriceFeed_Addr = "0xd702dd976fb76fffc2d3963d037dfdae5b04e593"
const OPPriceFeed_Addr = "0x0d276fc14719f9292d5c1ea2198673d1f4269246"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

describe("Test Uniswap", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const signer = await ethers.provider.getSigner(0)

        console.log(await helpers.time.latestBlock())

        const UniswapSwap = await ethers.getContractFactory("UniswapSwap")
        const uniswapSwap = await UniswapSwap.deploy(
            12, // wait [seconds]
            100 // slippage = 1%
        )
        await uniswapSwap.waitForDeployment()
        console.log("Uniswap Swap contract deployed: ", await uniswapSwap.getAddress())

        // Transfer USDC to owner.
        // const whaleUSDC = await ethers.getImpersonatedSigner(USDCWhale_Addr)
        // const whaleUsdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(whaleUSDC)
        // await whaleUsdc.transfer(await owner.getAddress(), '1000000000') // 1,000 USDC
        // console.log("Transferred USDC")

        // Transfer DAI to owner.
        // const whaleDAI = await ethers.getImpersonatedSigner(DAIWhale_Addr)
        // const whaleDai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(whaleDAI)
        // await whaleDai.transfer(await owner.getAddress(), ethers.parseEther('1000')) // 1,000 DAI
        // console.log("Transferred DAI")

        // Transfer wETH to owner.
        const whaleWETH = await ethers.getImpersonatedSigner(WETHWhale_Addr)
        const whaleWeth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(whaleWETH)
        await whaleWeth.transfer(await owner.getAddress(), ethers.parseEther('1')) // 1,000 USDC
        console.log("Transferred wETH")

        // Transfer wBTC to owner.
        const whaleWBTC = await ethers.getImpersonatedSigner(WBTCWhale_Addr)
        const whaleWbtc = (await ethers.getContractAt(WBTC_ABI, WBTC_Addr)).connect(whaleWBTC)
        await whaleWbtc.transfer(await owner.getAddress(), '10000000') // 0.1 wBTC
        console.log("Transferred wBTC")

        // Transfer OP to owner.
        const whaleOP = await ethers.getImpersonatedSigner(OPWhale_Addr)
        const whaleOp = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(whaleOP)
        await whaleOp.transfer(await owner.getAddress(), ethers.parseEther('1000')) // 1,000 OP
        console.log("Transferred OP")

        // wETH => wBTC (+ WBTC => wETH).
        await uniswapSwap.setPath(
            WETH_Addr,
            '3000',
            NULL_Addr,
            0,
            WBTC_Addr
        )
        console.log('Set wETH <=> wBTC')

        // OP (=> wETH) => wBTC (+ wBTC (=> wETH) => OP).
        await uniswapSwap.setPath(
            OP_Addr,
            '3000',
            WETH_Addr,
            '3000',
            WBTC_Addr
        )
        console.log('Set OP <=> wBTC')

        // Set USDC => DAI swap route (+ DAI => USDC).
        // await uniswapSwap.setPath(
        //     USDC_Addr,
        //     '',
        //     NULL_Addr,
        //     0,
        //     DAI_Addr
        // )
        // console.log("Set USDC => DAI route")

        // Set wETH (=> USDC) => DAI swap route (+ DAI (=> USDC) => wETH).
        // await uniswapSwap.setPath(
        //     WETH_Addr,
        //     '',
        //     USDC_Addr,
        //     '',
        //     DAI_Addr
        // )

        // Set ETH (=> wETH) => USDC swap route (+ wETH => USDC; USDC (=> wETH) => ETH; + USDC => wETH).
        // await uniswapSwap.setPath(
        //     WETH_Addr,
        //     '',
        //     NULL_Addr,
        //     0,
        //     USDC_Addr
        // )
        // console.log("Set wETH => DAI route")

        await uniswapSwap.setDecimals(WBTC_Addr, 8);
        await uniswapSwap.setDecimals(OP_Addr, 18);
        console.log("Set decimals")

        await uniswapSwap.setPriceFeed(WBTC_Addr, WBTCPriceFeed_Addr)
        await uniswapSwap.setPriceFeed(OP_Addr, OPPriceFeed_Addr)
        console.log("Set price feeds")

        // const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        // const dai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(signer)
        const weth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(signer)
        const wbtc = (await ethers.getContractAt(WBTC_ABI, WBTC_Addr)).connect(signer)
        const op = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(signer)

        // await usdc.approve(await velodromeSwap.getAddress(), await usdc.balanceOf(await owner.getAddress()))
        // await dai.approve(await velodromeSwap.getAddress(), await dai.balanceOf(await owner.getAddress()))
        await weth.approve(await uniswapSwap.getAddress(), await weth.balanceOf(await owner.getAddress()))
        await wbtc.approve(await uniswapSwap.getAddress(), await wbtc.balanceOf(await owner.getAddress()))
        await op.approve(await uniswapSwap.getAddress(), await op.balanceOf(await owner.getAddress()))
        console.log("Approved")

        return { uniswapSwap, weth, wbtc, op, owner }
    }

    it("Should swap wETH for wBTC", async function() {

        const { uniswapSwap, weth, wbtc, owner } = await loadFixture(deploy)

        await uniswapSwap.exactInput(
            await weth.balanceOf(await owner.getAddress()),
            WETH_Addr,
            WBTC_Addr
        )

        console.log("wBTC bal: ", await wbtc.balanceOf(await uniswapSwap.getAddress()))
    })

    it("Should swap wBTC for wETH and unwrap", async function() {

        const { uniswapSwap, weth, wbtc, owner } = await loadFixture(deploy)

        await uniswapSwap.exactInput(
            await wbtc.balanceOf(await owner.getAddress()),
            WBTC_Addr,
            WETH_Addr
        )

        console.log("wETH bal: ", await weth.balanceOf(await uniswapSwap.getAddress()))

        await uniswapSwap.unwrap(
            // await weth.balanceOf(await uniswapSwap.getAddress())
            // '1577337806852'
        )

        console.log("ETH bal: ", await ethers.provider.getBalance(await uniswapSwap.getAddress()))
    })

    it("Should swap OP for wBTC", async function() {

        const { uniswapSwap, op, wbtc, owner } = await loadFixture(deploy)

        await uniswapSwap.exactInput(
            await op.balanceOf(await owner.getAddress()),
            OP_Addr,
            WBTC_Addr
        )

        console.log("wBTC bal: ", await wbtc.balanceOf(await uniswapSwap.getAddress()))
    })

    it("Should swap wBTC for OP", async function() {

        const { uniswapSwap, op, wbtc, owner } = await loadFixture(deploy)

        await uniswapSwap.exactInput(
            await wbtc.balanceOf(await owner.getAddress()),
            WBTC_Addr,
            OP_Addr
        )

        console.log("OP bal: ", await op.balanceOf(await uniswapSwap.getAddress()))
    })

    it("Should swap ETH for wBTC", async function() {

        const { uniswapSwap, wbtc, weth, owner } = await loadFixture(deploy)

        console.log("ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))

        await uniswapSwap.exactInput(
            ethers.parseEther('1'),
            WETH_Addr,
            WBTC_Addr,
            {value: ethers.parseEther('1')}
        )

        console.log("wBTC bal: ", await wbtc.balanceOf(await uniswapSwap.getAddress()))
        // Should be 0.
        console.log("wETH bal: ", await weth.balanceOf(await uniswapSwap.getAddress()))
        console.log("ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))
    })
})