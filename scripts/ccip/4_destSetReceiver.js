/* global ethers */

const { ethers } = require('hardhat')

const SEPOLIA_CHAIN_SELECTOR = "16015286601757825753"
const OPTIMISM_GOERLI_CHAIN_SELECTOR = "2664363617261496610"
const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"
const OP_CHAIN_SELECTOR = "3734403246176062136"

async function main() {

    const cofiUnbridge = await ethers.getContractAt(
        "CofiUnbridge",
        "0x82E55a92611E1D8319bBB63e154AA0833755c819"
    )

    await cofiUnbridge.setReceiver(
        OP_CHAIN_SELECTOR,
        "0x9afd8dA81B76CDB7734BF025de7bc2c5D3C9A55E", // entry bridge
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