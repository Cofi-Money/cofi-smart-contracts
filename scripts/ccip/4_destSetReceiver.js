/* global ethers */

const { ethers } = require('hardhat')

const SEPOLIA_CHAIN_SELECTOR = "16015286601757825753"
const OPTIMISM_GOERLI_CHAIN_SELECTOR = "2664363617261496610"
const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"

async function main() {

    const bridgeExit = await ethers.getContractAt(
        "COFIBridgeExit",
        "0xd75F5608f4a38A75F2435f652164c138B2eb9A29"
    )

    await bridgeExit.setReceiver(
        MUMBAI_CHAIN_SELECTOR,
        "0x82E55a92611E1D8319bBB63e154AA0833755c819", // entry bridge
        true
    )
    console.log("Receiver set")

    // console.log(await bridgeExit.receiver(OPTIMISM_GOERLI_CHAIN_SELECTOR))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});