/* global ethers */

const { ethers } = require('hardhat')

const SEPOLIA_CHAIN_SELECTOR = "16015286601757825753"
const OPTIMISM_GOERLI_CHAIN_SELECTOR = "2664363617261496610"
const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"
const OP_CHAIN_SELECTOR = "3734403246176062136"

async function main() {

    const bridgeExit = await ethers.getContractAt(
        "COFIBridgeExit",
        "0xd75F5608f4a38A75F2435f652164c138B2eb9A29"
    )

    await bridgeExit.setReceiver(
        OP_CHAIN_SELECTOR,
        "0x913bcCb4e85C16F08731de7c2510d512AaFfF8F4", // entry bridge
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