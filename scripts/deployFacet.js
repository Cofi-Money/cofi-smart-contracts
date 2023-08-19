/* global ethers */

const { ethers } = require('hardhat')

async function main() {

    const Helper1Facet = await ethers.getContractFactory("Helper1Facet")
    const helper1Facet = await Helper1Facet.deploy()
    await helper1Facet.waitForDeployment()
    console.log('Helper1Facet deployed: ', await helper1Facet.getAddress())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});