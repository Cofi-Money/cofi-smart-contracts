/* global ethers */

const { ethers } = require('hardhat')
const helpers = require('@nomicfoundation/hardhat-network-helpers');

async function main() {

    const signer = await ethers.provider.getSigner(0)

    // Deposit
    const cofiMoney = (await ethers.getContractAt('COFIMoney', '0x3c9F3b896EC6cC7AF79f5d1E127FD1e84940da4e')).connect(signer)

    // console.log(await cofiMoney.getEstimatedCofiOut(
    //     '100000000',
    //     '0x68f180fcCe6836688e9084f035309E29Bf0A2095',
    //     '0x0395F6F10C8594Cef335E4DfB898bE37F766cBf2'
    // ))

    // console.log(await cofiMoney.getDecimals('0x68f180fcCe6836688e9084f035309E29Bf0A2095'))

    // console.log(await cofiMoney.getDecimals('0x0b840B4A75b83077F9FC66F64c33739c647D352c'))

    // await cofiMoney.exitCofi(
    //     '100000000000000',
    //     '0x0000000000000000000000000000000000000000',
    //     '0x0395F6F10C8594Cef335E4DfB898bE37F766cBf2',
    //     '0x5fd20F920525aA638afa163a4AE59eA27351225c',
    //     '0x5fd20F920525aA638afa163a4AE59eA27351225c',
    //     {gasLimit: "25000000"}
    // )

    // await cofiMoney.cofiToUnderlying(
    //     '5000000000000000000',
    //     '0x8924ad39beEB4f8B778A1CcA6CB7CE89788eA895',
    //     '0x5fd20F920525aA638afa163a4AE59eA27351225c',
    //     '0x5fd20F920525aA638afa163a4AE59eA27351225c',
    //     {gasLimit: "25000000"}
    // )

    const res = await cofiMoney.getVault('0x8924ad39beEB4f8B778A1CcA6CB7CE89788eA895')
    console.log(res)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});