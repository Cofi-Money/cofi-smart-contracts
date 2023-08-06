/* global ethers */

const { ethers } = require('hardhat')
const helpers = require('@nomicfoundation/hardhat-network-helpers');

async function main() {

    const usdc = (await ethers.getContractAt('COFIMoney', diamondAddr)).connect(signer)

    // Deposit
    const cofiMoney = (await ethers.getContractAt('COFIMoney', diamondAddr)).connect(signer)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});