/* global ethers */

const { ethers } = require('hardhat')

const SEPOLIA_ROUTER = "0xD0daae2231E9CB96b94C8512223533293C3693Bf"
const SEPOLIA_LINK = "0x779877A7B0D9E8603169DdbD7836e478b4624789"
const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"
const ARBITRUM_GOERLI_CHAIN_SELECTOR = "6101244977088475029"

async function main() {

    const BridgeEntry = await ethers.getContractFactory("COFIBridgeEntry")
    const bridgeEntry = await BridgeEntry.deploy(
        SEPOLIA_ROUTER,
        SEPOLIA_LINK,
        "0x0f28dE21b407448f6EC578481445C2CF752Ef10a", // cofi
        "0x23f0618e3ccBbAc605d6Ed0f85D3ce581E64df2f", // vault
        ARBITRUM_GOERLI_CHAIN_SELECTOR,
        "0x62f1B9A589571bf348cd5826042c7AfF2deBe4ee", // destShare
        "0xEc3EA01AEbb8de0d0C7B67cD16584ae196F60784" // exit bridge
    )
    await bridgeEntry.waitForDeployment()
    console.log("COFI Bridge Entry deployed: ", await bridgeEntry.getAddress())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});