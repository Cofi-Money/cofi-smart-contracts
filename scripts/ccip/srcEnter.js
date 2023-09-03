/* global ethers */

const { ethers } = require('hardhat')

const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"
const ARBITRUM_GOERLI_CHAIN_SELECTOR = "6101244977088475029"

async function main() {

    const accounts = await ethers.getSigners()
    const owner = accounts[0]

    const erc20 = await ethers.getContractAt(
        "ERC20Token",
        "0x0f28dE21b407448f6EC578481445C2CF752Ef10a"
    )

    await erc20.mint(await owner.getAddress(), ethers.parseEther('1000'), {gasLimit: "30000000"})
    console.log("Minted assets to owner")

    await erc20.approve(
        "0x8c284bdE38c33605Fe833A2b6F4C09aD4875e027", // bridge entry
        ethers.parseEther('1000')
    )
    console.log("Approved Bridge spend")

    console.log(await erc20.allowance(
        await owner.getAddress(),
        "0x8c284bdE38c33605Fe833A2b6F4C09aD4875e027" // bridge entry
    ))

    // const bridgeEntry = await ethers.getContractAt(
    //     "COFIBridgeEntry",
    //     "0x8c284bdE38c33605Fe833A2b6F4C09aD4875e027"
    // )

    // await bridgeEntry.setVault(
    //     "0x0f28dE21b407448f6EC578481445C2CF752Ef10a",
    //     "0x23f0618e3ccBbAc605d6Ed0f85D3ce581E64df2f"
    // )

    // console.log(await erc20.allowance(
    //     "0x8c284bdE38c33605Fe833A2b6F4C09aD4875e027", // bridge entry
    //     "0x23f0618e3ccBbAc605d6Ed0f85D3ce581E64df2f" // vault
    // ))

    // await bridgeEntry.setMandateFee(true)

    // const fee = await bridgeEntry.getFeeETH(
    //     "0x0f28dE21b407448f6EC578481445C2CF752Ef10a", // cofi
    //     ARBITRUM_GOERLI_CHAIN_SELECTOR,
    //     ethers.parseEther('100'),
    //     await owner.getAddress()
    // )
    // console.log("fee: ", fee)

    // // Ensure ETH is sent to entry and exit contracts beforehand.
    // await bridgeEntry.enter(
    //     "0x0f28dE21b407448f6EC578481445C2CF752Ef10a",
    //     ARBITRUM_GOERLI_CHAIN_SELECTOR,
    //     ethers.parseEther('100'),
    //     await owner.getAddress(),
    //     {value: ethers.parseEther('0.001')}
    // )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});