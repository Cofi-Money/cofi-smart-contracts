/* global ethers */

const { ethers } = require('hardhat')

const SEPOLIA_CHAIN_SELECTOR = "16015286601757825753"

async function main() {

    const bridgeExit = await ethers.getContractAt(
        "COFIBridgeExit",
        "0xEc3EA01AEbb8de0d0C7B67cD16584ae196F60784"
    )

    await bridgeExit.setReceiver(
        SEPOLIA_CHAIN_SELECTOR,
        "0x8c284bdE38c33605Fe833A2b6F4C09aD4875e027" // entry bridge
    )
    console.log("Receiver set")

    console.log(await bridgeExit.receiver(SEPOLIA_CHAIN_SELECTOR))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});