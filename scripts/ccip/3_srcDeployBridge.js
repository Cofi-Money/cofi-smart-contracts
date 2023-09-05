/* global ethers */

const { ethers } = require('hardhat')

const SEPOLIA_ROUTER = "0xD0daae2231E9CB96b94C8512223533293C3693Bf"
const MUMBAI_ROUTER = "0x70499c328e1E2a3c41108bd3730F6670a44595D1"
const OPTIMISM_GOERLI_ROUTER = "0xEB52E9Ae4A9Fb37172978642d4C141ef53876f26"
const FUJI_ROUTER = "0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8"
const SEPOLIA_LINK = "0x779877A7B0D9E8603169DdbD7836e478b4624789"
const MUMBAI_LINK = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"
const OPTIMISM_GOERLI_LINK = "0xdc2CC710e42857672E7907CF474a69B63B93089f"
const FUJI_LINK = "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846"
const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"
const ARBITRUM_GOERLI_CHAIN_SELECTOR = "6101244977088475029"
const FUJI_CHAIN_SELECTOR = "14767482510784806043"

async function main() {

    const BridgeEntry = await ethers.getContractFactory("COFIBridgeEntry")
    const bridgeEntry = await BridgeEntry.deploy(
        FUJI_ROUTER,
        FUJI_LINK,
        "0x23f0618e3ccBbAc605d6Ed0f85D3ce581E64df2f", // cofi
        "0x746C78bCB4106D2a37ebAD36552c1249b2Bd41bB", // vault
        FUJI_CHAIN_SELECTOR,
        "0x87Cf8659222d322D2b6b6B485d997eBf4C2Cc2E7", // destShare
        "0xaF772601Fb01660Ef40A9934691e50B357364BF3" // exit bridge
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