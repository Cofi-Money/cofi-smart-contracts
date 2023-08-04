/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const wETH_ABI = require("./abi/WETH.json")
const beefyERC4626Wrapper_ABI = require('./abi/beefyERC4626Wrapper.json')
const beefyVaultV7_ABI = require('./abi/beefyVaultV7.json')

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const wETH_Addr = "0x4200000000000000000000000000000000000006"
const wmooExactlyUSDC_Addr = "0x3a524ed2846C57f167a9284a74E0Fd04E2295786"
const wmooExactlyETH_Addr = "0x983Cb232571dE5B3fcaB42Ef0a42594cE7772ced"
const mooExactlyUSDC_Addr = "0xE7db4eA58560D4678DF204165D1f50d18185BC89"
const mooExactlyETH_Addr = "0x0Bf7616889d0ae18382d9715eAc00a3302e9aB92"
const whale_Addr = "0xee55c2100C3828875E0D65194311B8eF0372C6d9"
const whaleMooExactlyUsdc_Addr = "0x8AFEdbE65d451fa9Ba80637c8Ef4eec48DE52da3"
const whaleMooExactlyEth_Addr = "0x9a31EC2df5D42Aa0537ff845b01512112d94a7a4"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

describe("Test Beefy Exactly wrappers", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const whitelister = accounts[1]
        const backupOwner = accounts[2]
        const feeCollector = accounts[3]
        const signer = await ethers.provider.getSigner(0)
        const backupSigner = await ethers.provider.getSigner(1)
        const whaleSigner = await ethers.getImpersonatedSigner(whale_Addr)
        const whaleMooExactlyUsdcSigner = await ethers.getImpersonatedSigner(whaleMooExactlyUsdc_Addr)
        const whaleMooExactlyEthSigner = await ethers.getImpersonatedSigner(whaleMooExactlyEth_Addr)

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
        'PointFacet'
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
            vUSDC:  wmooExactlyUSDC_Addr,
            vETH:   wmooExactlyETH_Addr,
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

        /* Whitelist user */
        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)
        await cofiMoney.setWhitelist((await owner.getAddress()), "1")
        console.log("Whitelisted user")
        await cofiMoney.setWhitelist((await backupOwner.getAddress()), "1")
        console.log("Whitelisted 2nd user")

        /* Obtain funds */
        const whaleUsdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(whaleSigner)
        await whaleUsdc.transfer((await owner.getAddress()), "1000000000") // 1,000 USDC
        console.log("Transferred USDC to user")
        await whaleUsdc.transfer((await backupOwner.getAddress()), "1000000000") // 1,000 USDC
        console.log("Transferred USDC to 2nd user")
        const whaleWeth = (await ethers.getContractAt(wETH_ABI, wETH_Addr)).connect(whaleSigner)
        await whaleWeth.transfer((await owner.getAddress()), "1000000000000000000") // 1 wETH
        console.log("Transferred wETH to user")
        await whaleWeth.transfer((await backupOwner.getAddress()), "1000000000000000000") // 1 wETH
        console.log("Transferred wETH to 2nd user")

        /* Get asset contracts */
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        const weth = (await ethers.getContractAt(wETH_ABI, wETH_Addr)).connect(signer)

        /* Get Beefy contracts */
        const wmooExactlyUSDC = await ethers.getContractAt(
            beefyERC4626Wrapper_ABI,
            wmooExactlyUSDC_Addr
        )
        const wmooExactlyETH = await ethers.getContractAt(
            beefyERC4626Wrapper_ABI,
            wmooExactlyETH_Addr
        )
        const mooExactlyUSDC = await ethers.getContractAt(
            beefyVaultV7_ABI,
            mooExactlyUSDC_Addr
        )
        const mooExactlyETH = await ethers.getContractAt(
            beefyVaultV7_ABI,
            mooExactlyETH_Addr
        )

        /* Initial USDC deposit */
        await usdc.approve(await diamond.getAddress(), "1000000000") // 1,000 USDC
        await cofiMoney.underlyingToFi(
            "1000000000", // underlying [6 decimaos]
            "997500000000000000000", // 0.25% slippage fi [18 decimals]
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Wrapper mooExactlyUSDC bal: ", await mooExactlyUSDC.balanceOf(wmooHopUSDC_Addr))
        console.log("t0 Diamond wmooExactlyUSDC bal: ", await wmooExactlyUSDC.balanceOf(await diamond.getAddress()))

        /* Initial wETH deposit */
        await weth.approve(await diamond.getAddress(), "1000000000000000000") // 1 wETH
        await cofiMoney.underlyingToFi(
            "1000000000000000000", // underlying [18 decimaos]
            "997500000000000000", // 0.25% slippage fi [18 decimals]
            await fiETH.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Wrapper mooExactlyUSDC bal: ", await mooExactlyETH.balanceOf(wmooHopUSDC_Addr))
        console.log("t0 Diamond wmooExactlyUSDC bal: ", await wmooExactlyETH.balanceOf(await diamond.getAddress()))

        /* Simulate fiUSD yield distribution */
        const whaleMooExactlyUsdc = mooExactlyUSDC.connect(whaleMooExactlyUsdcSigner)
        await whaleMooExactlyUsdc.transfer(wmooExactlyUSDC_Addr, "100000000") // "100" mooExactlyUSDC
        // await cofiMoney.rebase(await fiUSD.getAddress())
        console.log("t1 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t1 Wrapper mooExactlyUSDC bal: ", await mooExactlyUSDC.balanceOf(wmooExactlyUSDC_Addr))
        // Will be the same as t0
        console.log("t1 Diamond wmooExactlyUSDC bal: ", await wmooExactlyUSDC.balanceOf(await diamond.getAddress()))
        console.log("t1 User fiUSD yield earned: ", await fiUSD.getYieldEarned(await owner.getAddress()))        

        /* Simulate fiETH yield distribution */
        const whaleMooExactlyEth = mooExactlyETH.connect(whaleMooExactlyEthSigner)
        await whaleMooExactlyEth.transfer(wmooExactlyETH_Addr, "100000000000000000") // 0.1 mooExactlyETH
        // await cofiMoney.rebase(await fiETH.getAddress())
        console.log("t1 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        console.log("t1 Wrapper mooExactlyETH bal: ", await mooExactlyETH.balanceOf(wmooExactlyETH_Addr))
        // Will be the same as t0
        console.log("t1 Diamond wmooExactlyETH bal: ", await wmooExactlyETH.balanceOf(await diamond.getAddress()))
        console.log("t1 User fiETH yield earned: ", await fiETH.getYieldEarned(await owner.getAddress()))

        const backupOwnerAddr = await backupOwner.getAddress()
        await cofiMoney.setWhitelist(backupOwner, "1")

        return { owner, backupSigner, backupOwnerAddr, fiUSD, fiETH, cofiMoney, mooExactlyUSDC,
            wmooExactlyUSDC, mooExactlyETH, wmooExactlyETH, whaleMooExactlyUsdc,
            whaleMooExactlyEth, feeCollector, diamond }
    }

    it("Should deposit", async function() {

        const { owner, backupSigner, backupOwnerAddr, fiUSD, fiETH, cofiMoney, mooExactlyUSDC,
        wmooExactlyUSDC, mooExactlyETH, wmooExactlyETH, whaleMooExactlyUsdc,
        whaleMooExactlyEth, feeCollector, diamond } = await loadFixture(deploy)

        /* Initial fiUSD deposit 2nd user */
        const _usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(backupSigner)
        await _usdc.approve(await cofiMoney.getAddress(), "1000000000") // 1,000 USDC
        const _cofiMoney = (await ethers.getContractAt('COFIMoney', await cofiMoney.getAddress()))
            .connect(backupSigner)
        await _cofiMoney.underlyingToFi(
            "1000000000", // underlying [6 decimaos]
            "997500000000000000000", // 0.25% slippage fi [18 decimals]
            await fiUSD.getAddress(),
            backupOwnerAddr,
            backupOwnerAddr,
            NULL_Addr
        )
        console.log("t2 2nd User fiUSD bal: ", await fiUSD.balanceOf(backupOwnerAddr))
        console.log("t2 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t2 Wrapper mooExactlyUSDC bal: ", await mooExactlyUSDC.balanceOf(wmooHopUSDC_Addr))
        console.log("t2 Diamond wmooExactlyUSDC bal: ", await wmooExactlyUSDC.balanceOf(await diamond.getAddress()))

        /* Initial fiETH deposit 2nd user */
        const _weth = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(backupSigner)
        await _weth.approve(await cofiMoney.getAddress(), "1000000000000000000") // 1 wETH
        await cofiMoney.underlyingToFi(
            "1000000000000000000", // underlying [18 decimaos]
            "9975000000000000000", // 0.25% slippage fi [18 decimals]
            await fiETH.getAddress(),
            backupOwnerAddr,
            backupOwnerAddr,
            NULL_Addr
        )
        console.log("t2 2nd User fiETH bal: ", await fiETH.balanceOf(backupOwnerAddr))
        console.log("t2 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        console.log("t2 Wrapper mooExactlyETH bal: ", await mooExactlyETH.balanceOf(wmooHopETH_Addr))
        console.log("t2 Diamond wmooExactlyETH bal: ", await wmooExactlyETH.balanceOf(await diamond.getAddress()))

        /* Simulate fiUSD yield distribution */
        await whaleMooExactlyUsdc.transfer(wmooExactlyUSDC_Addr, "50000000") // "50" mooExactlyUSDC
        await cofiMoney.rebase(await fiUSD.getAddress())
        console.log("t3 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t3 2nd User fiUSD bal: ", await fiUSD.balanceOf(backupOwnerAddr))
        console.log("t3 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t3 Wrapper mooExactlyUSDC bal: ", await mooExactlyUSDC.balanceOf(wmooExactlyUSDC_Addr))
        // Will be the same as t0
        console.log("t3 Diamond wmooExactlyUSDC bal: ", await wmooExactlyUSDC.balanceOf(await diamond.getAddress()))
        console.log("t3 User fiUSD yield earned: ", await fiUSD.getYieldEarned(await owner.getAddress()))
        console.log("t3 2nd User fiUSD yield earned: ", await fiUSD.getYieldEarned(backupOwnerAddr))    

        /* Simulate fiETH yield distribution */
        await whaleMooExactlyEth.transfer(wmooExactlyETH_Addr, "50000000000000000") // 0.05 mooExactlyETH
        await cofiMoney.rebase(await fiETH.getAddress())
        console.log("t3 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t3 2nd User fiETH bal: ", await fiETH.balanceOf(backupOwnerAddr))
        console.log("t3 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        console.log("t3 Wrapper mooExactlyETH bal: ", await mooExactlyETH.balanceOf(wmooExactlyETH_Addr))
        // Will be the same as t0
        console.log("t3 Diamond wmooExactlyETH bal: ", await wmooExactlyETH.balanceOf(await diamond.getAddress()))
        console.log("t3 User fiETH yield earned: ", await fiETH.getYieldEarned(await owner.getAddress()))
        console.log("t3 2nd User fiETH yield earned: ", await fiETH.getYieldEarned(backupOwnerAddr))

        /* Redeem fiUSD 2nd user */

    })
})