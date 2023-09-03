/* global ethers */

const { ethers } = require('hardhat')

const MUMBAI_ROUTER = "0x70499c328e1E2a3c41108bd3730F6670a44595D1"
const MUMBAI_LINK = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"
const ARBITRUM_GOERLI_ROUTER = "0x88E492127709447A5ABEFdaB8788a15B4567589E"
const ARBITRUM_GOERLI_LINK = "0xd14838A68E8AFBAdE5efb411d5871ea0011AFd28"
const SEPOLIA_CHAIN_SELECTOR = "16015286601757825753"

async function main() {

    // Deploy Mock ERC20 "Asset" (e.g., coUSD).
    const ERC20 = await ethers.getContractFactory("ERC20Token")
    const erc20 = await ERC20.deploy(
        "Polygon Wrapped COFI Dollar (ETH)",
        "matcoUSDeth",
        18
    )
    await erc20.waitForDeployment()
    console.log("arbcoUSDeth address: ", await erc20.getAddress())

    // Ensure ETH resides at this contract after deploying.
    const BridgeExit = await ethers.getContractFactory("COFIBridgeExit")
    const bridgeExit = await BridgeExit.deploy(
        ARBITRUM_GOERLI_ROUTER,
        ARBITRUM_GOERLI_LINK,
        await erc20.getAddress(), // destShare
        "0x0f28dE21b407448f6EC578481445C2CF752Ef10a", // srcAsset
        SEPOLIA_CHAIN_SELECTOR
    )
    await bridgeExit.waitForDeployment()
    console.log("COFI Bridge Exit deployed: ", await bridgeExit.getAddress())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});