/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const wETH_ABI = require("./abi/WETH.json")
const beefyERC4626Wrapper_ABI = require('./abi/beefyERC4626Wrapper.json')

const wETH_Addr = "0x4200000000000000000000000000000000000006"
const wmooExactlyETH_Addr = "0x983Cb232571dE5B3fcaB42Ef0a42594cE7772ced"
const whaleWETH_Addr = "0xee55c2100C3828875E0D65194311B8eF0372C6d9"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

describe("Test Beefy Exactly wrapper", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const whitelister = accounts[1]
        const backupOwner = accounts[2]
        const feeCollector = accounts[3]
        const signer = await ethers.provider.getSigner(0)
        const backupSigner = await ethers.provider.getSigner(1)
        const whaleWETHSigner = await ethers.getImpersonatedSigner(whaleWETH_Addr)

        console.log(await helpers.time.latestBlock())

        const wmooHopETH = await ethers.getContractAt(
            beefyERC4626Wrapper_ABI,
            wmooExactlyETH_Addr
        )

        const FIETH = await ethers.getContractFactory("FiToken")
        const fiETH = await FIETH.deploy(
            "COFI Ethereum",
            "fiETH"
        )
        await fiETH.waitForDeployment()
        console.log("fiETH deployed: " + await fiETH.getAddress())

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
        const diamond_Addr = await diamond.getAddress()

        // Set Diamond address in FiToken contract.
        await fiETH.setApp(await diamond.getAddress())
        console.log("Diamond address set in fiETH")

        // Deploy DiamondInit
        // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
        // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
        const DiamondInit = await ethers.getContractFactory('InitDiamond')
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
        'PartnerFacet',
        'PointFacet',
        'SupplyAdminFacet',
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
            fiETH:  await fiETH.getAddress(),
            vETH:   wmooExactlyETH_Addr,
            wETH:   wETH_Addr,
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

        /* Whitelist user */
        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)
        await cofiMoney.setWhitelist((await owner.getAddress()), "1")
        console.log("Whitelisted user")
        await cofiMoney.setWhitelist((await backupOwner.getAddress()), "1")
        console.log("Whitelisted 2nd user")

        /* Obtain funds */
        const _weth = (await ethers.getContractAt(wETH_ABI, wETH_Addr)).connect(whaleWETHSigner)
        await _weth.transfer((await owner.getAddress()), "1000000000000000000") // 1 wETH
        console.log("Transferred wETH to user")
        await _weth.transfer((await backupOwner.getAddress()), "1000000000000000000") // 1 wETH
        console.log("Transferred wETH to 2nd user")

        const weth = (await ethers.getContractAt(wETH_ABI, wETH_Addr)).connect(signer)

        return { owner, backupOwner, fiETH, cofiMoney, weth }
    }

    it("Should deposit", async function() {

        const { cofiMoney, owner, fiETH, weth } = await loadFixture(deploy)

        /* Initial deposit */
        await weth.approve(await cofiMoney.getAddress(), "500000000000000000") // 0.5 wETH
        await cofiMoney.underlyingToFi(
            "500000000000000000", // underlyingIn
            "498750000000000000", // 0.25% slippage
            await fiETH.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
    })
})