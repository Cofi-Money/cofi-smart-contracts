/* global ethers */

const { ethers } = require('hardhat')

const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"
const ARBITRUM_GOERLI_CHAIN_SELECTOR = "6101244977088475029"
const FUJI_CHAIN_SELECTOR = "14767482510784806043"

async function main() {

    const accounts = await ethers.getSigners()
    const owner = accounts[0]

    const erc20 = await ethers.getContractAt(
        "ERC20Token",
        "0x23f0618e3ccBbAc605d6Ed0f85D3ce581E64df2f"
    )

    // await erc20.approve(
    //     "0x82E55a92611E1D8319bBB63e154AA0833755c819", // bridge entry
    //     ethers.parseEther('1000'),
    //     // {gasLimit: "30000000"}
    // )
    // console.log("Approved Bridge spend")

    const bridgeEntry = await ethers.getContractAt(
        "COFIBridgeEntry",
        "0x82E55a92611E1D8319bBB63e154AA0833755c819"
    )

    const fee = await bridgeEntry.getFeeETH(
        "0x23f0618e3ccBbAc605d6Ed0f85D3ce581E64df2f", // cofi
        FUJI_CHAIN_SELECTOR,
        ethers.parseEther('100'),
        await owner.getAddress()
    )
    console.log("fee: ", fee)

    // Ensure ETH is sent to entry and exit contracts beforehand.
    await bridgeEntry.enter(
        "0x23f0618e3ccBbAc605d6Ed0f85D3ce581E64df2f",
        FUJI_CHAIN_SELECTOR,
        ethers.parseEther('100'),
        await owner.getAddress(),
        // {value: fee},
        // {gasLimit: "30000000"}
    )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});