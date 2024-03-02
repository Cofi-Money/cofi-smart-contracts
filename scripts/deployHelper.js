/* global ethers */

const { ethers } = require('hardhat')

// async function main() {

//     const Helper = await ethers.getContractFactory("Helper")
//     const helper = await Helper.deploy(
//         "0x3c9F3b896EC6cC7AF79f5d1E127FD1e84940da4e",
//         "0x8924ad39beEB4f8B778A1CcA6CB7CE89788eA895",
//         "0xd371a070E505e3d553B8382A7874D177A1EE23A3",   // 940000000
//         "0x0395F6F10C8594Cef335E4DfB898bE37F766cBf2"    // 635044896
//     )
//     await helper.waitForDeployment()
//     console.log('Helper deployed: ', await helper.getAddress())
// }

async function main() {

    const Hunter = await ethers.getContractFactory("YieldHunter")
    const hunter = await Hunter.deploy(
        "0x3c9F3b896EC6cC7AF79f5d1E127FD1e84940da4e"
    )
    await hunter.waitForDeployment()
    console.log('Hunter deployed: ', await hunter.getAddress())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});