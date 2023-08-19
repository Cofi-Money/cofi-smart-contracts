/* global ethers */

const { ethers } = require('hardhat')
const helpers = require('@nomicfoundation/hardhat-network-helpers');

async function main() {

    const signer = await ethers.provider.getSigner(0)

    // Deposit
    const cofiMoney = (await ethers.getContractAt('COFIMoney', '0xD5D0AEb7231d37229De09dB4556477E2857abB98')).connect(signer)

    // Deposit USDC
    await cofiMoney.underlyingToCofi(
        '10000000',
        '0',
        '0xEA6676493CcAe182dbddeE68be564078F4B6f7F1', // coUSD
        '0x5fd20F920525aA638afa163a4AE59eA27351225c',
        '0x5fd20F920525aA638afa163a4AE59eA27351225c',
        '0x0000000000000000000000000000000000000000'
    )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});