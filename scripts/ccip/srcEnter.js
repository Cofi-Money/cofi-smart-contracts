/* global ethers */

const { ethers } = require('hardhat')

const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"
const ARBITRUM_GOERLI_CHAIN_SELECTOR = "6101244977088475029"
const FUJI_CHAIN_SELECTOR = "14767482510784806043"
const POLY_CHAIN_SELECTOR = "4051577828743386545"

async function main() {

    const accounts = await ethers.getSigners()
    const owner = accounts[0]

    const erc20 = await ethers.getContractAt(
        "ERC20Token",
        "0x008aAbc5b60AF6D944e70383f94c9178A7809428" // X
    )

    await erc20.approve(
        "0x913bcCb4e85C16F08731de7c2510d512AaFfF8F4", // bridge entry X
        ethers.parseEther('1000'),
        // {gasLimit: "30000000"}
    )
    console.log("Approved Bridge spend")

    const bridgeEntry = await ethers.getContractAt(
        "COFIBridgeEntry",
        "0x913bcCb4e85C16F08731de7c2510d512AaFfF8F4" // X
    )

    // const fee = await bridgeEntry.getFeeETH(
    //     "0x23f0618e3ccBbAc605d6Ed0f85D3ce581E64df2f", // cofi
    //     FUJI_CHAIN_SELECTOR,
    //     ethers.parseEther('100'),
    //     await owner.getAddress()
    // )
    // console.log("fee: ", fee)

    // Ensure ETH is sent to entry and exit contracts beforehand.
    await bridgeEntry.enter(
        "0x008aAbc5b60AF6D944e70383f94c9178A7809428", // X
        POLY_CHAIN_SELECTOR,
        ethers.parseEther('100'),
        await owner.getAddress(),
        // {value: fee},
        {gasLimit: "30000000"}
    )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});