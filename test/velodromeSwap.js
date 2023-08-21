/* global ethers */

const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const DAI_ABI = require("./abi/DAI_Optimism.json")
const WETH_ABI = require("./abi/WETH.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const DAI_Addr = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"
const WETH_Addr = "0x4200000000000000000000000000000000000006"
const USDCWhale_Addr = "0x16224283bE3f7C0245d9D259Ea82eaD7fcB8343d"
const WETHWhale_Addr = "0x0Eb21ed8543789C79bEd81D85b13eA31E7aC805b"
const DAIWhale_Addr = "0x7B281D987201fC47eAD18c3eDb493A2Fa4B93d4E"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

describe("Test swapping USDC to DAI via Velodrome", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const signer = await ethers.provider.getSigner(0)

        console.log(await helpers.time.latestBlock())

        const VelodromeSwap = await ethers.getContractFactory("VelodromeSwap")
        const velodromeSwap = await VelodromeSwap.deploy(
            12, // wait [seconds]
            200 // slippage = 2%
        )
        await velodromeSwap.waitForDeployment()
        console.log("Velodrome Swap contract deployed: ", await velodromeSwap.getAddress())

        // Transfer USDC to owner.
        const whaleUSDC = await ethers.getImpersonatedSigner(USDCWhale_Addr)
        const whaleUsdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(whaleUSDC)
        await whaleUsdc.transfer(await owner.getAddress(), '1000000000') // 1,000 USDC
        console.log("Transferred USDC")

        // Transfer DAI to owner.
        const whaleDAI = await ethers.getImpersonatedSigner(DAIWhale_Addr)
        const whaleDai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(whaleDAI)
        await whaleDai.transfer(await owner.getAddress(), ethers.parseEther('1000')) // 1,000 DAI
        console.log("Transferred DAI")

        // Transfer wETH to owner.
        const whaleWETH = await ethers.getImpersonatedSigner(WETHWhale_Addr)
        const whaleWeth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(whaleWETH)
        await whaleWeth.transfer(await owner.getAddress(), ethers.parseEther('1')) // 1,000 USDC
        console.log("Transferred wETH")

        // Set USDC => DAI swap route (+ DAI => USDC).
        await velodromeSwap.setRoute(
            USDC_Addr,
            DAI_Addr,
            NULL_Addr,
            [true, false] // 2nd param does not matter.
        )
        console.log("Set USDC => DAI route")

        // Set wETH (=> USDC) => DAI swap route (+ DAI (=> USDC) => wETH).
        await velodromeSwap.setRoute(
            WETH_Addr,
            DAI_Addr,
            USDC_Addr,
            [false, true]
        )
        console.log("Set wETH => DAI + ETH => wETH => DAI route")

        // Set ETH (=> wETH) => USDC swap route (+ wETH => USDC; USDC (=> wETH) => ETH; + USDC => wETH).
        await velodromeSwap.setRoute(
            WETH_Addr,
            USDC_Addr,
            NULL_Addr,
            [false, true] // 2nd param does not matter.
        )
        console.log("Set wETH => DAI route")

        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        const dai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(signer)
        const weth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(signer)

        await usdc.approve(await velodromeSwap.getAddress(), await usdc.balanceOf(await owner.getAddress()))
        await dai.approve(await velodromeSwap.getAddress(), await dai.balanceOf(await owner.getAddress()))
        await weth.approve(await velodromeSwap.getAddress(), await weth.balanceOf(await owner.getAddress()))
        console.log("Approved")

        return { velodromeSwap, usdc, dai, weth, owner }
    }

    it("Should swap USDC for DAI", async function() { // P

        const { velodromeSwap, dai } = await loadFixture(deploy)

        await velodromeSwap.swapExactTokensForTokens(
            '200000000',
            USDC_Addr,
            DAI_Addr
        )

        console.log("Dai bal: ", await dai.balanceOf(await velodromeSwap.getAddress()))
    })

    it("Should swap DAI for USDC", async function() { // P

        const { velodromeSwap, usdc } = await loadFixture(deploy)

        await velodromeSwap.swapExactTokensForTokens(
            ethers.parseEther('200'),
            DAI_Addr,
            USDC_Addr
        )

        console.log("USDC bal: ", await usdc.balanceOf(await velodromeSwap.getAddress()))
    })

    it("Should swap wETH for DAI", async function() { // P

        const { velodromeSwap, dai } = await loadFixture(deploy)

        await velodromeSwap.swapExactTokensForTokens(
            ethers.parseEther('1'),
            WETH_Addr,
            DAI_Addr
        )

        console.log("Dai bal: ", await dai.balanceOf(await velodromeSwap.getAddress()))
    })

    it("Should swap DAI for wETH", async function() { // P

        const { velodromeSwap, weth } = await loadFixture(deploy)

        await velodromeSwap.swapExactTokensForTokens(
            ethers.parseEther('1000'),
            DAI_Addr,
            WETH_Addr
        )

        console.log("wETH bal: ", await weth.balanceOf(await velodromeSwap.getAddress()))
    })

    it("Should swap wETH for USDC", async function() {

        const { velodromeSwap, usdc } = await loadFixture(deploy)

        await velodromeSwap.swapExactTokensForTokens(
            ethers.parseEther('1'),
            WETH_Addr,
            USDC_Addr
        )

        console.log("USDC bal: ", await usdc.balanceOf(await velodromeSwap.getAddress()))
    })

    it("Should swap USDC for wETH", async function() {

        const { velodromeSwap, weth } = await loadFixture(deploy)

        await velodromeSwap.swapExactTokensForTokens(
            '1000000000',
            USDC_Addr,
            WETH_Addr
        )

        console.log("wETH bal: ", await weth.balanceOf(await velodromeSwap.getAddress()))
    })

    it("Should swap ETH for USDC", async function() {

        const { velodromeSwap, usdc } = await loadFixture(deploy)

        await velodromeSwap.swapExactETHForTokens(
            // 0, // amountOutMin will be later handled by Diamond.
            USDC_Addr,
            {value: ethers.parseEther('1')}
        )

        console.log("USDC bal: ", await usdc.balanceOf(await velodromeSwap.getAddress()))
    })

    it("Should swap ETH for DAI", async function() {

        const { velodromeSwap, dai } = await loadFixture(deploy)

        await velodromeSwap.swapExactETHForTokens(
            // 0, // amountOutMin will be later handled by Diamond.
            DAI_Addr,
            {value: ethers.parseEther('1')}
        )

        console.log("Dai bal: ", await dai.balanceOf(await velodromeSwap.getAddress()))
    })

    it("Should swap USDC for ETH", async function() {

        const { velodromeSwap, owner } = await loadFixture(deploy)

        console.log("ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))

        await velodromeSwap.swapExactTokensForETH(
            '100000000',
            USDC_Addr
        )

        console.log("ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))
    })

    it("Should swap DAI for ETH", async function() {

        const { velodromeSwap, owner } = await loadFixture(deploy)

        console.log("ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))

        await velodromeSwap.swapExactTokensForETH(
            ethers.parseEther('100'),
            DAI_Addr
        )

        console.log("ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))
    })
})