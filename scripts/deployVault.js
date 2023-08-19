/* global ethers */

const { ethers } = require('hardhat')

const USDC_Addr = '0x7F5c764cBc14f9669B88837ca1490cCa17c31607'
const wETH_Addr = '0x4200000000000000000000000000000000000006'
const OP_Addr = "0x4200000000000000000000000000000000000042"
const COMPTROLLER_Addr = "0x60cf091cd3f50420d50fd7f707414d0df4751c58"
const soUSDC_Addr = '0xEC8FEa79026FfEd168cCf5C627c7f486D77b765F'
const soWETH_Addr = '0xf7B5965f5C117Eb1B5450187c9DcFccc3C317e8E'
const App_Addr = '0xD5D0AEb7231d37229De09dB4556477E2857abB98'
const USDCPriceFeed_Addr = "0x16a9fa2fda030272ce99b29cf780dfa30361e0f3"
const ETHPriceFeed_Addr = "0x13e3ee699d1909e989722e753853ae30b17e08c5"

async function main() {

    const WSOUSDC = await ethers.getContractFactory("CompoundV2ERC4626Reinvest")
    const wsoUSDC = await WSOUSDC.deploy(
        USDC_Addr,
        OP_Addr,
        soUSDC_Addr,
        COMPTROLLER_Addr,
        USDCPriceFeed_Addr,
        "1000000000000000000", // amountInMin = 1 OP
        "200", // slippage = 2%
        "12" // wait = 12 seconds
    )
    await wsoUSDC.waitForDeployment()
    console.log("Deployed wsoUSDC to: ", await wsoUSDC.getAddress())

    const WSOETH = await ethers.getContractFactory("CompoundV2ERC4626Reinvest")
    const wsoETH = await WSOETH.deploy(
        wETH_Addr,
        OP_Addr,
        soWETH_Addr,
        COMPTROLLER_Addr,
        ETHPriceFeed_Addr,
        "1000000000000000000", // amountInMin = 1 OP
        "200", // slippage = 2%
        "12" // wait = 12 seconds
    )
    await wsoUSDC.waitForDeployment()
    console.log("Deployed wsoETH to: ", await wsoETH.getAddress())

    const signer = await ethers.provider.getSigner(0)
    const cofiMoney = (await ethers.getContractAt('COFIMoney', App_Addr)).connect(signer)
    await cofiMoney.setHarvestable(await wsoUSDC.getAddress(), '1')
    await cofiMoney.setHarvestable(await wsoETH.getAddress(), '1')
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});