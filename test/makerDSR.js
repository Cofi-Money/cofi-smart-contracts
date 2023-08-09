/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Ethereum mainnet */

const DAI_ABI = require('./abi/DAI.json')
const sDAI_ABI = require('./abi/sDAI.json')

const DAI_Addr = '0x6B175474E89094C44Da98b954EedeAC495271d0F'
const sDAI_Addr = '0x83F20F44975D03b1b09e64809B757c47f942BEeA'
const whale_Addr = '0x8A610c1C93da88c59F51A6264A4c70927814B320'
const NULL_Addr = "0x0000000000000000000000000000000000000000"

describe("Test mock vaults", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const whitelister = accounts[1]
        const backupOwner = accounts[2]
        const feeCollector = accounts[3]
        const signer = await ethers.provider.getSigner(0)
        const whaleSigner = await ethers.getImpersonatedSigner(whale_Addr)

        console.log(await helpers.time.latestBlock())

        const COFITOKEN = await ethers.getContractFactory("COFIRebasingToken")
        const coUSD = await COFITOKEN.deploy(
            "COFI Dollar",
            "coUSD"
        )
        await coUSD.waitForDeployment()
        console.log("coUSD deployed: " + await coUSD.getAddress())

        // Deploy DiamondCutFacet
        const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet")
        const diamondCutFacet = await DiamondCutFacet.deploy()
        await diamondCutFacet.waitForDeployment()
        console.log("DiamondCutFacet deployed: ", await diamondCutFacet.getAddress())
        
        // Deploy Diamond
        const Diamond = await ethers.getContractFactory("Diamond")
        const diamond = await Diamond.deploy(
            await owner.getAddress(),
            await diamondCutFacet.getAddress()
        )
        await diamond.waitForDeployment()
        console.log("Diamond deployed: ", await diamond.getAddress())

        // Set Diamond address in COFIRebasingToken contracts.
        await coUSD.setApp(await diamond.getAddress())
        console.log("Diamond address set in coUSD")

        // Deploy mock vault
        const Vault = await ethers.getContractFactory("Vault")
        const vDAI = await Vault.deploy("Mock Vault DAI", "vDAI", DAI_Addr)
        await vDAI.waitForDeployment()
        console.log("Mock Vault DAI deployed: ", await vDAI.getAddress())

        // Deploy DiamondInit
        // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
        // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
        const DiamondInit = await ethers.getContractFactory('InitDiamondEthereum')
        const diamondInit = await DiamondInit.deploy()
        await diamondInit.waitForDeployment()
        console.log('DiamondInit deployed:', await diamondInit.getAddress())

        // Deploy facets
        console.log('')
        console.log('Deploying facets')
        const FacetNames = [
        'DiamondLoupeFacet',
        'OwnershipFacet',
        'SupplyFacet',
        'AccessFacet',
        'PointFacet',
        'YieldFacet'
        ]
        const cut = []
        for (const FacetName of FacetNames) {
            const Facet = await ethers.getContractFactory(FacetName)
            const facet = await Facet.deploy()
            await facet.waitForDeployment()
            console.log(`${FacetName} deployed: ${await facet.getAddress()}`)
            cut.push({
                facetAddress: await facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: getSelectors(facet)
            })
        }
       
        const initArgs = [{
            coUSD:  await coUSD.getAddress(),
            vDAI:   sDAI_Addr,
            DAI:    DAI_Addr,
            roles: [
                await whitelister.getAddress(),
                await backupOwner.getAddress(),
                await feeCollector.getAddress()
            ]
        }]

        // Upgrade diamond with facets
        console.log('')
        console.log('Diamond Cut:', cut)
        const diamondCut = await ethers.getContractAt('IDiamondCut', await diamond.getAddress())
        let tx
        let receipt
        // Call to init function
        let functionCall = diamondInit.interface.encodeFunctionData('init', initArgs)
        tx = await diamondCut.diamondCut(cut, await diamondInit.getAddress(), functionCall)
        console.log('Diamond cut tx: ', tx.hash)
        receipt = await tx.wait()
        if (!receipt.status) {
        throw Error(`Diamond upgrade failed: ${tx.hash}`)
        }
        console.log('Completed diamond cut')

        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)

        /* Obtain funds */
        const whaleDai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(whaleSigner)
        await whaleDai.transfer((await owner.getAddress()), ethers.parseEther('1000')) // 1,000 DAI
        console.log("Transferred DAI to user")

        /* Get asset contracts */
        const dai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(signer)
        const sdai = (await ethers.getContractAt(sDAI_ABI, sDAI_Addr)).connect(signer)

        await dai.approve(await diamond.getAddress(), ethers.parseEther('1000')) // 1,000 DAI
        await cofiMoney.underlyingToCofi(
            ethers.parseEther('100'),
            ethers.parseEther('99.75'),
            await coUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Diamond sDAI bal: ", await sdai.balanceOf(await diamond.getAddress()))

        /* Simulate coUSD yield distribution */
        await whaleDai.transfer((await sdai.getAddress()), ethers.parseEther('100')) // 100 DAI
        console.log('Transferred DAI to sDAI')
        await cofiMoney.rebase(await coUSD.getAddress())
        console.log("t1 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
        // Will be the same as t0
        console.log("t1 Diamond sDAI bal: ", await sdai.balanceOf(await diamond.getAddress()))
        console.log("t1 User coUSD yield earned: ", await coUSD.getYieldEarned(await owner.getAddress()))        

        return { owner, cofiMoney, coUSD, dai, sdai, vDAI, whaleDai, feeCollector }
    }

    it("Should deposit and rebase", async function() {

        await loadFixture(deploy)
    })

    it("Should deposit again, rebase, and redeem", async function() {

        const { owner, cofiMoney, coUSD, dai, sdai, whaleDai, feeCollector } = await loadFixture(deploy)

        /* Second coUSD deposit */
        await cofiMoney.underlyingToCofi(
            ethers.parseEther('100'),
            ethers.parseEther('99.75'),
            await coUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t2 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        console.log("t2 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t2 User coUSD yield earned: ", await coUSD.getYieldEarned(await owner.getAddress()))

        /* Second coUSD yield distribution */
        await whaleDai.transfer((await sdai.getAddress()), ethers.parseEther('1000')) // 1000 DAI
        await cofiMoney.rebase(await coUSD.getAddress())
        console.log("t3 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        console.log("t3 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
        // Will be the same as t0
        console.log("t3 Diamond sDAI bal: ", await sdai.balanceOf(await cofiMoney.getAddress()))
        console.log("t3 User coUSD yield earned: ", await coUSD.getYieldEarned(await owner.getAddress()))
        
        /* Redeem coUSD balance */
        await coUSD.approve(await cofiMoney.getAddress(), await coUSD.balanceOf(await owner.getAddress()))
        await cofiMoney.cofiToUnderlying(
            await coUSD.balanceOf(await owner.getAddress()),
            "0",
            await coUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
        )
        console.log("t4 User DAI bal: ", await dai.balanceOf(await owner.getAddress()))
        console.log("t4 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        console.log("t4 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t4 Diamond sDAI bal: ", await sdai.balanceOf(await cofiMoney.getAddress()))
        console.log("t4 User coUSD yield earned: ", await coUSD.getYieldEarned(await owner.getAddress()))
    })

    // it("Should migrate to identical vault", async function() {

    //     const { owner, cofiMoney, coETH, weth, vETH, whaleWeth, feeCollector, Vault } = await loadFixture(deploy)

    //     // Transfer 2x wETH buffer to Diamond
    //     await whaleWeth.transfer(await cofiMoney.getAddress(), "200000000000000000") // 0.2 wETH

    //     // Deploy newVault
    //     const _vETH = await Vault.deploy("_Vault ETH", "_vETH", wETH_Addr)
    //     await _vETH.waitForDeployment()
    //     console.log("_vETH deployed: ", await _vETH.getAddress())

    //     /* Migrate */
    //     await cofiMoney.migrate(await coETH.getAddress(), await _vETH.getAddress())

    //     console.log("t2 User coETH bal: ", await coETH.balanceOf(await owner.getAddress()))
    //     console.log("t2 Fee Collector coETH bal: ", await coETH.balanceOf(await feeCollector.getAddress()))
    //     // Should be depleted
    //     console.log("t2 Vault wETH bal: ", await weth.balanceOf(await vETH.getAddress()))
    //     // Should be depleted
    //     console.log("t2 Diamond vETH bal: ", await vETH.balanceOf(await cofiMoney.getAddress()))
    //     // Should have 0.1 wETH remaining
    //     console.log("t2 Diamond wETH bal: ", await weth.balanceOf(await cofiMoney.getAddress()))
    //     console.log("t2 User coETH yield earned: ", await coETH.getYieldEarned(await owner.getAddress()))
    //     console.log("t2 _Vault wETH bal: ", await weth.balanceOf(await _vETH.getAddress()))
    //     console.log("t2 Diamond _vETH bal: ", await _vETH.balanceOf(await cofiMoney.getAddress()))

    //     /* Deposit again */
    //     await cofiMoney.underlyingToCofi(
    //         "100000000000000000", // 0.1 wETH underlying [18 decimaos]
    //         "99750000000000000", // 0.25% slippage fi [18 decimals]
    //         await coETH.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr
    //     )
    //     console.log("t3 User coETH bal: ", await coETH.balanceOf(await owner.getAddress()))
    //     console.log("t3 Fee Collector coETH bal: ", await coETH.balanceOf(await feeCollector.getAddress()))
    //     // Should be depleted
    //     console.log("t3 Vault wETH bal: ", await weth.balanceOf(await vETH.getAddress()))
    //     // Should be depleted
    //     console.log("t3 Diamond vETH bal: ", await vETH.balanceOf(await cofiMoney.getAddress()))
    //     console.log("t3 User coETH yield earned: ", await coETH.getYieldEarned(await owner.getAddress()))
    //     console.log("t3 _Vault wETH bal: ", await weth.balanceOf(await _vETH.getAddress()))
    //     console.log("t3 Diamond _vETH bal: ", await _vETH.balanceOf(await cofiMoney.getAddress()))

    //     /* Redeem coETH balance */
    //     await coETH.approve(await cofiMoney.getAddress(), await coETH.balanceOf(await owner.getAddress()))
    //     await cofiMoney.cofiToUnderlying(
    //         await coETH.balanceOf(await owner.getAddress()),
    //         "0",
    //         await coETH.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //     )
    //     console.log("t4 User wETH bal: ", await weth.balanceOf(await owner.getAddress()))
    //     console.log("t4 User coETH bal: ", await coETH.balanceOf(await owner.getAddress()))
    //     console.log("t4 Fee Collector coETH bal: ", await coETH.balanceOf(await feeCollector.getAddress()))
    //     console.log("t4 _Vault wETH bal: ", await weth.balanceOf(await _vETH.getAddress()))
    //     console.log("t4 Diamond _vETH bal: ", await _vETH.balanceOf(await cofiMoney.getAddress()))
    //     console.log("t4 User coETH yield earned: ", await coETH.getYieldEarned(await owner.getAddress()))
    // })
})