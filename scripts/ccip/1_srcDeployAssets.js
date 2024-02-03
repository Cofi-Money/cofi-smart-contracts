/* global ethers */

const { ethers } = require('hardhat')

async function main() {

    const accounts = await ethers.getSigners()
    const owner = accounts[0]

    // Deploy Mock ERC20 "Asset" (e.g., coUSD).
    // const ERC20 = await ethers.getContractFactory("ERC20Token")
    // const erc20 = await ERC20.deploy(
    //     "COFI Dollar (Optimism)",
    //     "coUSDop",
    //     18,
    //     // {gasLimit: "30000000"}
    // )
    // await erc20.waitForDeployment()
    // console.log("coUSDop address: ", await erc20.getAddress())

    // const erc20 = await ethers.getContractAt(
    //     "ERC20Token",
    //     "0x008aAbc5b60AF6D944e70383f94c9178A7809428"
    // )
    // console.log(await owner.getAddress())
    // // Mint tokens to owner.
    // await erc20.mint(
    //     await owner.getAddress(),
    //     '1000000000000000000000',
    //     // {gasLimit: "30000000"}
    // )
    // console.log(await erc20.balanceOf(await owner.getAddress()))

    // Deploy Mock "Vault" (e.g. wcoUSD)
    const Vault = await ethers.getContractFactory("Vault")
    const vault = await Vault.deploy(
        "Wrapped COFI Dollar (Optimism)",
        "wcoUSDop",
        '0x008aAbc5b60AF6D944e70383f94c9178A7809428'
        // {gasLimit: "30000000"}
    )
    await vault.waitForDeployment()
    console.log("wcoUSDop address: ", await vault.getAddress())
    // wcoUSDop address:  0x775D92358A9AC2CD9c8aDD5247Cf5BE3aB1f357A
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});