/* global ethers */

const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const DAI_ABI = require("./abi/DAI_Optimism.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const DAI_Addr = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"
const Factory_Addr = "0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a"
const Router_Addr = "0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858"
const USDCWhale_Addr = "0x16224283bE3f7C0245d9D259Ea82eaD7fcB8343d"

describe("Test swapping USDC to DAI via Velodrome", function() {

    async function deploy() {

        const VelodromeSwap = await ethers.getContractFactory("VelodromeSwap")
        const velodromeSwap = await VelodromeSwap.deploy(
            Factory_Addr,
            Router_Addr
        )
        await velodromeSwap.waitForDeployment()
        console.log("Velodrome Swap contract deployed: ", await velodromeSwap.getAddress())

        const whale = await ethers.getImpersonatedSigner(USDCWhale_Addr)
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(whale)
        await usdc.transfer(await velodromeSwap.getAddress(), '1000000000') // 1,000 USDC

        const signer = await ethers.provider.getSigner(0)
        const dai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(signer)

        return { velodromeSwap, usdc, dai }
    }

    it("Should swap USDC for DAI", async function() {

        const { velodromeSwap, usdc, dai } = await loadFixture(deploy)

        await velodromeSwap.swapExactTokensForTokens(
            '1000000000',
            USDC_Addr,
            DAI_Addr,
            true
        )

        console.log("Dai bal: ", await dai.balanceOf(await velodromeSwap.getAddress()))
    })
})