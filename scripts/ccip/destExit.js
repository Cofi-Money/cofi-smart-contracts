/* global ethers */

const { ethers } = require('hardhat')

async function main() {

    const accounts = await ethers.getSigners()
    const owner = accounts[0]

    const bridgeExit = await ethers.getContractAt(
        "COFIBridgeExit",
        "0x3421A038B62EcC0482008790DC79CDEe7FE0553b"
    )

    await bridgeExit.exit(
        "0x5b6643F3315E53a3463F11897c48491eFAaa5072",
        ethers.parseEther('25'),
        await owner.getAddress()
    )
    console.log("Exited")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});