/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const wETH_ABI = require("./abi/WETH.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const wETH_Addr = "0x4200000000000000000000000000000000000006"
const whale_Addr = "0x33A4C0070384725DbDf57Edf3d179F6891124517"
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

        const FIUSD = await ethers.getContractFactory("FiToken")
        const fiUSD = await FIUSD.deploy(
            "COFI Dollar",
            "fiUSD"
        )
        await fiUSD.waitForDeployment()
        console.log("fiUSD deployed: " + await fiUSD.getAddress())
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

        // Set Diamond address in FiToken contracts.
        await fiUSD.setApp(await diamond.getAddress())
        console.log("Diamond address set in fiUSD")
        await fiETH.setApp(await diamond.getAddress())
        console.log("Diamond address set in fiETH")

        // Deploy mock vaults
        const Vault = await ethers.getContractFactory("Vault")
        const vUSDC = await Vault.deploy("Vault USDC", "vUSDC", USDC_Addr)
        await vUSDC.waitForDeployment()
        console.log("USDC Mock Vault deployed: ", await vUSDC.getAddress())
        const vETH = await Vault.deploy("Vault ETH", "vETH", wETH_Addr)
        await vETH.waitForDeployment()
        console.log("wETH Mock Vault deployed: ", await vETH.getAddress())

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
            fiUSD:  await fiUSD.getAddress(),
            fiETH:  await fiETH.getAddress(),
            fiBTC:  NULL_Addr,
            vUSDC:  await vUSDC.getAddress(),
            vETH:   await vETH.getAddress(),
            vBTC:   NULL_Addr,
            USDC:   USDC_Addr,
            wETH:   wETH_Addr,
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

        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)

        /* Obtain funds */
        const whaleUsdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(whaleSigner)
        await whaleUsdc.transfer((await owner.getAddress()), "1000000000") // 1,000 USDC
        console.log("Transferred USDC to user")
        const whaleWeth = (await ethers.getContractAt(wETH_ABI, wETH_Addr)).connect(whaleSigner)
        await whaleWeth.transfer((await owner.getAddress()), "1000000000000000000") // 1 wETH
        console.log("Transferred wETH to user")

        /* Get asset contracts */
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        const weth = (await ethers.getContractAt(wETH_ABI, wETH_Addr)).connect(signer)

        await usdc.approve(await diamond.getAddress(), "1000000000") // 1,000 USDC
        await cofiMoney.underlyingToFi(
            "500000000", // underlying [6 decimaos]
            "498750000000000000000", // 0.25% slippage fi [18 decimals]
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Vault USDC bal: ", await usdc.balanceOf(await vUSDC.getAddress()))
        console.log("t0 Diamond vUSDC bal: ", await vUSDC.balanceOf(await diamond.getAddress()))

        await weth.approve(await diamond.getAddress(), "1000000000000000000") // 1 wETH
        await cofiMoney.underlyingToFi(
            "500000000000000000", // underlying [18 decimaos]
            "498750000000000000", // 0.25% slippage fi [18 decimals]
            await fiETH.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Vault wETH bal: ", await weth.balanceOf(await vETH.getAddress()))
        console.log("t0 Diamond vETH bal: ", await vETH.balanceOf(await diamond.getAddress()))

        /* Simulate fiUSD yield distribution */
        await whaleUsdc.transfer((await vUSDC.getAddress()), "10000000") // 10 USDC
        console.log('Transferred USDC to vUSDC')
        await cofiMoney.rebase(await fiUSD.getAddress())
        console.log("t1 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t1 Vault USDC bal: ", await usdc.balanceOf(await vUSDC.getAddress()))
        // Will be the same as t0
        console.log("t1 Diamond vUSDC bal: ", await vUSDC.balanceOf(await diamond.getAddress()))
        console.log("t1 User fiUSD yield earned: ", await fiUSD.getYieldEarned(await owner.getAddress()))        

        /* Simulate fiETH yield distribution */
        await whaleWeth.transfer((await vETH.getAddress()), "10000000000000000") // 0.01 wETH
        await cofiMoney.rebase(await fiETH.getAddress())
        console.log("t1 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        console.log("t1 Vault wETH bal: ", await weth.balanceOf(await vETH.getAddress()))
        // Will be the same as t0
        console.log("t1 Diamond vETH bal: ", await vETH.balanceOf(await diamond.getAddress()))
        console.log("t1 User fiETH yield earned: ", await fiETH.getYieldEarned(await owner.getAddress()))

        return { owner, cofiMoney, fiUSD, fiETH, usdc, weth, vUSDC, vETH, whaleUsdc, whaleWeth,
            feeCollector, Vault }
    }

    // it("Should deposit again, rebase, and redeem", async function() {

    //     const { owner, cofiMoney, fiUSD, usdc, vUSDC, whaleUsdc, feeCollector } = await loadFixture(deploy)

    //     /* Second fiUSD deposit */
    //     await cofiMoney.underlyingToFi(
    //         "500000000", // underlying [6 decimaos]
    //         "498750000000000000000", // 0.25% slippage fi [18 decimals]
    //         await fiUSD.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr
    //     )
    //     console.log("t2 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
    //     console.log("t2 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
    //     console.log("t2 Vault USDC bal: ", await usdc.balanceOf(await vUSDC.getAddress()))
    //     console.log("t2 User fiUSD yield earned: ", await fiUSD.getYieldEarned(await owner.getAddress()))

    //     /* Second fiUSD yield distribution */
    //     await whaleUsdc.transfer((await vUSDC.getAddress()), "10000000") // 10 USDC
    //     await cofiMoney.rebase(await fiUSD.getAddress())
    //     console.log("t3 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
    //     console.log("t3 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
    //     console.log("t3 Vault USDC bal: ", await usdc.balanceOf(await vUSDC.getAddress()))
    //     // Will be the same as t0
    //     console.log("t3 Diamond vUSDC bal: ", await vUSDC.balanceOf(await cofiMoney.getAddress()))
    //     console.log("t3 User fiUSD yield earned: ", await fiUSD.getYieldEarned(await owner.getAddress()))
        
    //     /* Redeem fiUSD balance */
    //     await fiUSD.approve(await cofiMoney.getAddress(), await fiUSD.balanceOf(await owner.getAddress()))
    //     await cofiMoney.fiToUnderlying(
    //         await fiUSD.balanceOf(await owner.getAddress()),
    //         "0",
    //         await fiUSD.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //     )
    //     console.log("t4 User USDC bal: ", await usdc.balanceOf(await owner.getAddress()))
    //     console.log("t4 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
    //     console.log("t4 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
    //     console.log("t4 Vault USDC bal: ", await usdc.balanceOf(await vUSDC.getAddress()))
    //     console.log("t4 Diamond vUSDC bal: ", await vUSDC.balanceOf(await cofiMoney.getAddress()))
    //     console.log("t4 User fiUSD yield earned: ", await fiUSD.getYieldEarned(await owner.getAddress()))
    // })

    // it("Should migrate to identical vault", async function() {

    //     const { owner, cofiMoney, fiETH, weth, vETH, whaleWeth, feeCollector, Vault } = await loadFixture(deploy)

    //     // Transfer 2x wETH buffer to Diamond
    //     await whaleWeth.transfer(await cofiMoney.getAddress(), "200000000000000000") // 0.2 wETH

    //     // Deploy newVault
    //     const _vETH = await Vault.deploy("_Vault ETH", "_vETH", wETH_Addr)
    //     await _vETH.waitForDeployment()
    //     console.log("_vETH deployed: ", await _vETH.getAddress())

    //     /* Migrate */
    //     await cofiMoney.migrate(await fiETH.getAddress(), await _vETH.getAddress())

    //     console.log("t2 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
    //     console.log("t2 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
    //     // Should be depleted
    //     console.log("t2 Vault wETH bal: ", await weth.balanceOf(await vETH.getAddress()))
    //     // Should be depleted
    //     console.log("t2 Diamond vETH bal: ", await vETH.balanceOf(await cofiMoney.getAddress()))
    //     // Should have 0.1 wETH remaining
    //     console.log("t2 Diamond wETH bal: ", await weth.balanceOf(await cofiMoney.getAddress()))
    //     console.log("t2 User fiETH yield earned: ", await fiETH.getYieldEarned(await owner.getAddress()))
    //     console.log("t2 _Vault wETH bal: ", await weth.balanceOf(await _vETH.getAddress()))
    //     console.log("t2 Diamond _vETH bal: ", await _vETH.balanceOf(await cofiMoney.getAddress()))

    //     /* Deposit again */
    //     await cofiMoney.underlyingToFi(
    //         "100000000000000000", // 0.1 wETH underlying [18 decimaos]
    //         "99750000000000000", // 0.25% slippage fi [18 decimals]
    //         await fiETH.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr
    //     )
    //     console.log("t3 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
    //     console.log("t3 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
    //     // Should be depleted
    //     console.log("t3 Vault wETH bal: ", await weth.balanceOf(await vETH.getAddress()))
    //     // Should be depleted
    //     console.log("t3 Diamond vETH bal: ", await vETH.balanceOf(await cofiMoney.getAddress()))
    //     console.log("t3 User fiETH yield earned: ", await fiETH.getYieldEarned(await owner.getAddress()))
    //     console.log("t3 _Vault wETH bal: ", await weth.balanceOf(await _vETH.getAddress()))
    //     console.log("t3 Diamond _vETH bal: ", await _vETH.balanceOf(await cofiMoney.getAddress()))

    //     /* Redeem fiETH balance */
    //     await fiETH.approve(await cofiMoney.getAddress(), await fiETH.balanceOf(await owner.getAddress()))
    //     await cofiMoney.fiToUnderlying(
    //         await fiETH.balanceOf(await owner.getAddress()),
    //         "0",
    //         await fiETH.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //     )
    //     console.log("t4 User wETH bal: ", await weth.balanceOf(await owner.getAddress()))
    //     console.log("t4 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
    //     console.log("t4 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
    //     console.log("t4 _Vault wETH bal: ", await weth.balanceOf(await _vETH.getAddress()))
    //     console.log("t4 Diamond _vETH bal: ", await _vETH.balanceOf(await cofiMoney.getAddress()))
    //     console.log("t4 User fiETH yield earned: ", await fiETH.getYieldEarned(await owner.getAddress()))
    // })

    it("Should migrate to CompoundV2ERC4626 vault", async function() {

        const { owner, cofiMoney, fiETH, weth, vETH, whaleWeth, feeCollector } = await loadFixture(deploy)

        // Transfer 2x wETH buffer to Diamond
        await whaleWeth.transfer(await cofiMoney.getAddress(), "200000000000000000") // 0.2 wETH

        const OP_Addr = "0x4200000000000000000000000000000000000042"
        const COMPTROLLER_Addr = "0x60cf091cd3f50420d50fd7f707414d0df4751c58"
        const sowETH_Addr = "0xf7B5965f5C117Eb1B5450187c9DcFccc3C317e8E"

        // Deploy newVault
        const Vault = await ethers.getContractFactory('CompoundV2ERC4626Reinvest')
        const _vETH = await Vault.deploy(
            wETH_Addr,
            OP_Addr,
            sowETH_Addr,
            COMPTROLLER_Addr,
            NULL_Addr, // Leave swap params blank for now
            "0",
            "0",
            "0"
        )
        await _vETH.waitForDeployment()
        console.log("_vETH deployed: ", await _vETH.getAddress())
        await _vETH.setAuthorized((await cofiMoney.getAddress()), "1")

        /* Migrate */
        // Rebase is not set to call harvest op
        await cofiMoney.migrate(await fiETH.getAddress(), await _vETH.getAddress())

        console.log("t2 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t2 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        // Should be depleted
        console.log("t2 Vault wETH bal: ", await weth.balanceOf(await vETH.getAddress()))
        // Should be depleted
        console.log("t2 Diamond vETH bal: ", await vETH.balanceOf(await cofiMoney.getAddress()))
        // Should have 0.1 wETH remaining
        console.log("t2 Diamond wETH bal: ", await weth.balanceOf(await cofiMoney.getAddress()))
        console.log("t2 User fiETH yield earned: ", await fiETH.getYieldEarned(await owner.getAddress()))
        console.log("t2 _Vault wETH bal: ", await weth.balanceOf(await _vETH.getAddress()))
        console.log("t2 Diamond _vETH bal: ", await _vETH.balanceOf(await cofiMoney.getAddress()))

        /* Deposit again */
        await cofiMoney.underlyingToFi(
            "100000000000000000", // 0.1 wETH underlying [18 decimaos]
            "99750000000000000", // 0.25% slippage fi [18 decimals]
            await fiETH.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t3 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t3 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        // Should be depleted
        console.log("t3 Vault wETH bal: ", await weth.balanceOf(await vETH.getAddress()))
        // Should be depleted
        console.log("t3 Diamond vETH bal: ", await vETH.balanceOf(await cofiMoney.getAddress()))
        console.log("t3 User fiETH yield earned: ", await fiETH.getYieldEarned(await owner.getAddress()))
        console.log("t3 _Vault wETH bal: ", await weth.balanceOf(await _vETH.getAddress()))
        console.log("t3 Diamond _vETH bal: ", await _vETH.balanceOf(await cofiMoney.getAddress()))

        /* Redeem fiETH balance */
        await fiETH.approve(await cofiMoney.getAddress(), await fiETH.balanceOf(await owner.getAddress()))
        await cofiMoney.fiToUnderlying(
            await fiETH.balanceOf(await owner.getAddress()),
            "0",
            await fiETH.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
        )
        console.log("t4 User wETH bal: ", await weth.balanceOf(await owner.getAddress()))
        console.log("t4 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t4 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        console.log("t4 _Vault wETH bal: ", await weth.balanceOf(await _vETH.getAddress()))
        console.log("t4 Diamond _vETH bal: ", await _vETH.balanceOf(await cofiMoney.getAddress()))
        console.log("t4 User fiETH yield earned: ", await fiETH.getYieldEarned(await owner.getAddress()))
    })
})