/* global ethers */

const { ethers } = require('hardhat')

async function main() {

    const bridgeEntry = await ethers.getContractAt(
        "COFIBridgeEntry",
        "0x171727e5D16C63683996962a05148f56c3a028A9"
    )
    // Ensure ETH is sent to entry and exit contracts beforehand.
    await bridgeEntry.setVault(
        "0x09a52a1c6093E61fEB5AB9E1597BbAfE72cC5992",
        "0xd75F5608f4a38A75F2435f652164c138B2eb9A29"
    )
    console.log("Vault set")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});