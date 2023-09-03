/* global ethers */

const { ethers } = require('hardhat')

async function main() {

    const accounts = await ethers.getSigners()
    const owner = accounts[0]

    // Deploy Mock ERC20 "Asset" (e.g., coUSD).
    const ERC20 = await ethers.getContractFactory("ERC20Token")
    const erc20 = await ERC20.deploy(
        "COFI Dollar (ETH)",
        "coUSDeth",
        18
    )
    await erc20.waitForDeployment()
    console.log("coUSDeth address: ", await erc20.getAddress())

    // Mint tokens to owner.
    await erc20.mint(await owner.getAddress(), ethers.parseEther('1000'))

    // Deploy Mock "Vault" (e.g. wcoUSD)
    const Vault = await ethers.getContractFactory("Vault")
    const vault = await Vault.deploy(
        "Wrapped COFI Dollar (ETH)",
        "wcoUSDeth",
        await erc20.getAddress()
    )
    await vault.waitForDeployment()
    console.log("wcoUSDeth address: ", await vault.getAddress())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});