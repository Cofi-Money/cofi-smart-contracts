/* global ethers */

const { ethers } = require('hardhat')

const MUMBAI_ROUTER = "0x70499c328e1E2a3c41108bd3730F6670a44595D1"
const MUMBAI_LINK = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"
const ARBITRUM_GOERLI_ROUTER = "0x88E492127709447A5ABEFdaB8788a15B4567589E"
const ARBITRUM_GOERLI_LINK = "0xd14838A68E8AFBAdE5efb411d5871ea0011AFd28"
const SEPOLIA_CHAIN_SELECTOR = "16015286601757825753"
const OPTIMISM_GOERLI_CHAIN_SELECTOR = "2664363617261496610"
const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"
const OPTIMISM_CHAIN_SELECTOR = "3734403246176062136"
const FUJI_ROUTER = "0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8"
const FUJI_LINK = "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846"
const BASE_ROUTER = "0x673AA85efd75080031d44fcA061575d1dA427A28"
const BASE_LINK = "0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196"
const POLY_ROUTER = "0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe" // v1.2
const POLY_LINK = "0xb0897686c545045aFc77CF20eC7A532E3120E0F1"

async function main() {

    // Don't forget to deploy to destination chain(!)

    const BridgedToken = await ethers.getContractFactory("BridgedToken")
    const bridgedToken = await BridgedToken.deploy(
        "COFI Dollar (OP)",
        "matcoUSD",
        18
        // {gasLimit: "30000000"}
    )
    await bridgedToken.waitForDeployment()
    console.log("matcoUSD address: ", await bridgedToken.getAddress())

    // const bridgedToken = await ethers.getContractAt(
    //     "BridgedToken",
    //     "0x187A99622d12A9d80f9C2E5F100f49afE0449025"
    // )

    // Ensure ETH resides at this contract after deploying.
    const CofiUnbridge = await ethers.getContractFactory("CofiUnbridge")
    const cofiUnbridge = await CofiUnbridge.deploy(
        POLY_ROUTER,
        POLY_LINK,
        await bridgedToken.getAddress(), // destShare
        "0x8924ad39beEB4f8B778A1CcA6CB7CE89788eA895", // srcAsset (e.g., coUSD)
        OPTIMISM_CHAIN_SELECTOR
    )
    await cofiUnbridge.waitForDeployment()
    console.log("Cofi Unbridge deployed: ", await cofiUnbridge.getAddress())

    // Set Unbridge contract
    await bridgedToken.setUnbridge(await cofiUnbridge.getAddress())
    console.log("Unbridge set")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});