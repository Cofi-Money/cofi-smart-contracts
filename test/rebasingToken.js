/* global ethers */

const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

describe("Test rebasing token", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const app = accounts[1]
        const alice = accounts[2]
        const signer = await ethers.provider.getSigner(0)
        const appSigner = await ethers.provider.getSigner(1)
        const aliceSigner = await ethers.provider.getSigner(2)

        console.log(await alice.getAddress())

        const coUSD = await hre.ethers.deployContract("COFIRebasingToken", 
            ["COFI Dollar", "coUSD", await app.getAddress()]
        );
        await coUSD.waitForDeployment()
        console.log('COFI Dollar deployed: ', await coUSD.getAddress())

        const _coUSD = coUSD.connect(appSigner)
        await _coUSD.mint(await alice.getAddress(), ethers.parseUnits('1000'))
        console.log('t0 Alice coUSD bal: ', await coUSD.balanceOf(await alice.getAddress()))
        console.log('t0 Alice coUSD free bal: ', await coUSD.freeBalanceOf(await alice.getAddress()))

        await _coUSD.lock(await alice.getAddress(), ethers.parseUnits('1100'))
        console.log('t1 Alice coUSD bal: ', await coUSD.balanceOf(await alice.getAddress()))
        console.log('t1 Alice coUSD free bal: ', await coUSD.freeBalanceOf(await alice.getAddress()))

        await _coUSD.changeSupply(ethers.parseUnits('1100'))
        console.log('t2 Alice coUSD bal: ', await coUSD.balanceOf(await alice.getAddress()))
        console.log('t2 Alice coUSD free bal: ', await coUSD.freeBalanceOf(await alice.getAddress()))

        await _coUSD.unlock(await alice.getAddress(), ethers.parseUnits('1100'))
        console.log('t3 Alice coUSD bal: ', await coUSD.balanceOf(await alice.getAddress()))
        console.log('t3 Alice coUSD free bal: ', await coUSD.freeBalanceOf(await alice.getAddress()))
    }

    it("Should execute desired functionality", async function() {

        await loadFixture(deploy)
  
    })
})