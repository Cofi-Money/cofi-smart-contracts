/* global ethers */

const { ethers } = require('hardhat')

const USDC_Addr = '0x7F5c764cBc14f9669B88837ca1490cCa17c31607'
const wETH_Addr = '0x4200000000000000000000000000000000000006'
const OP_Addr = "0x4200000000000000000000000000000000000042"
const soUSDC_Addr = '0xEC8FEa79026FfEd168cCf5C627c7f486D77b765F'
const soWETH_Addr = '0xf7B5965f5C117Eb1B5450187c9DcFccc3C317e8E'
const USDCPriceFeed_Addr = "0x16a9fa2fda030272ce99b29cf780dfa30361e0f3"
const ETHPriceFeed_Addr = "0x13e3ee699d1909e989722e753853ae30b17e08c5"
const YVUSDC_Addr = "0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2"
const YVUSDT_Addr = "0xFaee21D0f0Af88EE72BB6d68E54a90E6EC2616de"
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const StakingRewards_YVUSDC_Addr = "0xB2c04C55979B6CA7EB10e666933DE5ED84E6876b"
const USDT_Addr = "0x94b008aA00579c1307B0EF2c499aD98a8ce58e58"
const StakingRewards_YVUSDT_Addr = "0xf66932f225cA48856B7f97b6F060f4c0D244Af8E"
const USDTPriceFeed_Addr = "0xecef79e109e997bca29c1c0897ec9d7b03647f5e"
const COFIMoney_Addr = "0x3c9F3b896EC6cC7AF79f5d1E127FD1e84940da4e"

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "1500" // 15%
const wait = "12" // 12 seconds
const poolFee = "3000" // 0.3%

async function main() {

    /* Example script for adding a vault that has a new underlying */
    // Should be simulated in a forked env beforehand.

    // const signer = await ethers.provider.getSigner(0)
    // const cofiMoney = (await ethers.getContractAt(
    //     'COFIMoney',
    //     "0x3c9F3b896EC6cC7AF79f5d1E127FD1e84940da4e")
    // ).connect(signer)

    // // SwapRouteV3 set via Louper.
    // // SwapProtocol set via Louper.

    // // Set decimals
    // await cofiMoney.setDecimals(USDT_Addr, "6")
    // console.log("Decimals set")

    // // Set buffer
    // await cofiMoney.setBuffer(USDT_Addr, "10000000") // 10 USDT buffer

    // Transfer buffer.

    // // Deploy Yearn V2 USDT Wrapper
    // const WYVUSDC = await ethers.getContractFactory("YearnV2StakingRewards")
    // const wyvUSDC = await WYVUSDC.deploy(
    //     YVUSDT_Addr,
    //     YVOP_Addr,
    //     StakingRewards_YVUSDC_Addr,
    //     "0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3", // USDC price feed
    //     getRewardMin,
    //     amountInMin,
    //     slippage,
    //     wait,
    //     poolFee,
    //     "1",
    //     // {gasLimit: "30000000"}
    // )
    // await wyvUSDC.waitForDeployment()
    // console.log("wyvUSDC deployed: ", await wyvUSDC.getAddress())

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

    await wyvUSDT.setAuthorized(COFIMoney_Addr, "1")
    await wyvUSDT.setRewardShareReceiver(COFIMoney_Addr)

    // await cofiMoney.setHarvestable(await wsoETH.getAddress(), '1')
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});