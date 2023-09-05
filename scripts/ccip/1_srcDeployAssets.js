/* global ethers */

const { ethers } = require('hardhat')

async function main() {

    const accounts = await ethers.getSigners()
    const owner = accounts[0]

    // Deploy Mock ERC20 "Asset" (e.g., coUSD).
    const ERC20 = await ethers.getContractFactory("ERC20Token")
    const erc20 = await ERC20.deploy(
        "COFI Dollar (Polygon)",
        "coUSDmat",
        18,
        // {gasLimit: "30000000"}
    )
    await erc20.waitForDeployment()
    console.log("coUSDmat address: ", await erc20.getAddress())

    // const erc20 = await ethers.getContractAt(
    //     "ERC20Token",
    //     "0x0f28dE21b407448f6EC578481445C2CF752Ef10a"
    // )

    // Mint tokens to owner.
    await erc20.mint(
        await owner.getAddress(),
        ethers.parseEther('1000'),
        // {gasLimit: "30000000"}
    )
    console.log(await erc20.balanceOf(await owner.getAddress()))

    // Deploy Mock "Vault" (e.g. wcoUSD)
    const Vault = await ethers.getContractFactory("Vault")
    const vault = await Vault.deploy(
        "Wrapped COFI Dollar (Polygon)",
        "wcoUSDmat",
        await erc20.getAddress(),
        // {gasLimit: "30000000"}
    )
    await vault.waitForDeployment()
    console.log("wcoUSDmat address: ", await vault.getAddress())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});