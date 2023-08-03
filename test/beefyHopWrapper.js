/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const beefyERC4626Wrapper_ABI = require('./abi/beefyERC4626Wrapper.json')
const beefyVaultV6_ABI = require('./abi/beefyVaultV6.json')

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const mooHopUSDC_Addr = "0xE2f035f59De6a952FF699b4EDD0f99c466f25fEc"
const wmooHopUSDC_Addr = "0xe1bc3bC4102Fe8F0A49788b8185a920bD7B6839e"
const whaleUSDC = "0xee55c2100C3828875E0D65194311B8eF0372C6d9"
const whaleMooHopUSDC = "0x788e6f9d17e60e47d6d05424cb8608613ff07de7"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

describe("Test Beefy wrapper", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const whitelister = accounts[1]
        const backupOwner = accounts[2]
        const feeCollector = accounts[3]
        const signer = await ethers.provider.getSigner(0)
        // For obtaining underlying
        const whaleUsdcSigner = await ethers.getImpersonatedSigner(whaleUSDC)
        // For simulating rebase
        const whaleMooHopUsdcSigner = await ethers.getImpersonatedSigner(whaleMooHopUSDC)

        console.log(await helpers.time.latestBlock())

        /* Get Beefy contracts */
        const mooHopUSDC = await ethers.getContractAt(
            beefyVaultV6_ABI,
            mooHopUSDC_Addr
        )
        const wmooHopUSDC = await ethers.getContractAt(
            beefyERC4626Wrapper_ABI,
            wmooHopUSDC_Addr
        )

        // Deploy fiUSD
        const FIUSD = await ethers.getContractFactory("FiToken")
        const fiUSD = await FIUSD.deploy(
            "COFI Dollar",
            "fiUSD"
        )
        await fiUSD.waitForDeployment()
        console.log("fiUSD deployed: " + await fiUSD.getAddress())

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

        // Set Diamond address in FiToken contract.
        await fiUSD.setApp(await diamond.getAddress())
        console.log("Diamond address set in fiUSD")

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
       
        // Mark unused addresses as null for now.
        const initArgs = [{
            fiUSD:  await fiUSD.getAddress(),
            fiETH:  NULL_Addr,
            fiBTC:  NULL_Addr,
            vUSDC:  wmooHopUSDC_Addr,
            vETH:   NULL_Addr,
            vBTC:   NULL_Addr,
            USDC:   USDC_Addr,
            wETH:   NULL_Addr,
            wBTC:   NULL_Addr,
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

        /* Transfer user assets */
        const whaleUsdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(whaleUsdcSigner)
        await whaleUsdc.transfer((await owner.getAddress()), "1000000000") // 1,000 USDC
        console.log("Transferred USDC to user")
        await whaleUsdc.transfer((await backupOwner.getAddress()), "1000000000") // 1,000 USDC
        console.log("Transferred USDC to 2nd user")

        /* Initial deposit */
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        await usdc.approve(await diamond.getAddress(), "1000000000") // 1,000 USDC
        await cofiMoney.underlyingToFi(
            "1000000000", // underlying [6 decimaos]
            "997500000000000000", // 0.25% slippage fi [18 decimals]
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Wrapper mooHopUSDC bal: ", await mooHopUSDC.balanceOf(wmooHopUSDC_Addr))
        console.log("t0 Diamond wmooHopUSDC bal: ", await wmooHopUSDC.balanceOf(await diamond.getAddress()))

        /* Simulate yield distribution */
        const whaleMooHopUsdc = mooHopUSDC.connect(whaleUsdcSigner)
        await whaleMooHopUsdc.transfer(wmooHopUSDC_Addr, '10000000000000000000') // 10 mooHopUSDC [18 decimals]
        await cofiMoney.rebase(await fiUSD.getAddress())

        console.log("t1 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t1 Wrapper mooHopUSDC bal: ", await mooHopUSDC.balanceOf(wmooHopUSDC_Addr))
        // Will be the same as t0
        console.log("t1 Diamond wmooHopUSDC bal: ", await wmooHopUSDC.balanceOf(await diamond.getAddress()))
        console.log("t1 User fiUSD yield earned: ", await fiUSD.getYieldEarned(await owner.getAddress()))

        const backupOwnerAddr = await backupOwner.getAddress()

        return { owner, feeCollector, signer, backupSigner, backupOwnerAddr, fiUSD, mooHopUSDC, wmooHopUSDC,
        cofiMoney, diamond, usdc, whaleMooHopUsdc }
    }

    it("Should deposit, rebase, and redeem for 2nd user", async function() {

        const { owner, feeCollector, signer, backupSigner, backupOwner, fiUSD, mooHopUSDC, wmooHopUSDC,
        cofiMoney, diamond, usdc, backupOwnerAddr, whaleMooHopUsdc } = await loadFixture(deploy)

        /* 2nd deposit */
        const _usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(backupSigner)
        await _usdc.approve(await diamond.getAddress(), "1000000000") // 1,000 USDC
        const _cofiMoney = cofiMoney.connect(backupSigner)
        await _cofiMoney.underlyingToFi(
            "1000000000", // underlying [6 decimaos]
            "997500000000000000", // 0.25% slippage fi [18 decimals]
            await fiUSD.getAddress(),
            backupOwnerAddr,
            backupOwnerAddr,
            NULL_Addr
        )
        console.log("t2 2nd User fiUSD bal: ", await fiUSD.balanceOf(backupOwnerAddr))
        console.log("t2 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t2 Wrapper mooHopUSDC bal: ", await mooHopUSDC.balanceOf(wmooHopUSDC_Addr))
        console.log("t2 Diamond wmooHopUSDC bal: ", await wmooHopUSDC.balanceOf(await diamond.getAddress()))

        /* 2nd rebase */
        await whaleMooHopUsdc.transfer(wmooHopUSDC_Addr, '10000000000000000000') // 10 mooHopUSDC [18 decimals]
        await cofiMoney.rebase(await fiUSD.getAddress())
        console.log("t3 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t3 2nd User fiUSD bal: ", await fiUSD.balanceOf(backupOwnerAddr))
        console.log("t3 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t3 Wrapper mooHopUSDC bal: ", await mooHopUSDC.balanceOf(wmooHopUSDC_Addr))
        // Will be the same as t0
        console.log("t3 Diamond wmooHopUSDC bal: ", await wmooHopUSDC.balanceOf(await diamond.getAddress()))
        console.log("t3 User fiUSD yield earned: ", await fiUSD.getYieldEarned(await owner.getAddress()))
        console.log("t3 2nd User fiUSD yield earned: ", await fiUSD.getYieldEarned(backupOwnerAddr))

        /* Redeem */
        const _fiUSD = fiUSD.connect(backupSigner)
        await _fiUSD.approve(await diamond.getAddress(), await _fiUSD.balanceOf(backupOwnerAddr))
        await cofiMoney.fiToUnderlying(
            await _fiUSD.balanceOf(backupOwnerAddr),
            '0', // Leave for now
            await fiUSD.getAddress(),
            backupOwnerAddr,
            backupOwnerAddr
        )

        console.log("t4 2nd User fiUSD bal: ", await fiUSD.balanceOf(backupOwnerAddr))
        console.log("t4 2nd User USDC bal: ", await _usdc.balanceOf(backupOwnerAddr))
        console.log("t4 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        // Should be less
        console.log("t4 Wrapper mooHopUSDC bal: ", await mooHopUSDC.balanceOf(wmooHopUSDC_Addr))
        // Should be less
        console.log("t4 Diamond wmooHopUSDC bal: ", await wmooHopUSDC.balanceOf(await diamond.getAddress()))
    })

    // it("Should migrate", async function() {

    // })
})