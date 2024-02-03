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
const POLY_ROUTER = "0x3C3D92629A02a8D95D5CB9650fe49C3544f69B43"
const POLY_LINK = "0xb0897686c545045aFc77CF20eC7A532E3120E0F1"

async function main() {

    // Deploy Mock ERC20 "Asset" (e.g., coUSD).
    const ERC20 = await ethers.getContractFactory("ERC20Token")
    const erc20 = await ERC20.deploy(
        "P-W COFI Dollar (Op)",
        "pcoUSDop",
        18
        // {gasLimit: "30000000"}
    )
    await erc20.waitForDeployment()
    console.log("polycoUSDop address: ", await erc20.getAddress())

    // Ensure ETH resides at this contract after deploying.
    const BridgeExit = await ethers.getContractFactory("COFIBridgeExit")
    const bridgeExit = await BridgeExit.deploy(
        POLY_ROUTER,
        POLY_LINK,
        await erc20.getAddress(), // destShare
        "0x008aAbc5b60AF6D944e70383f94c9178A7809428", // srcAsset
        OPTIMISM_CHAIN_SELECTOR
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