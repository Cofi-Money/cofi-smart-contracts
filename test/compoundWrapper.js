/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const wETH_ABI = require("./abi/WETH.json")
const wBTC_ABI = require("./abi/WBTC.json")
const soTOKEN_ABI = require("./abi/SOTOKEN.json")
const OP_ABI = require("./abi/OP.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const wBTC_Addr = "0x68f180fcCe6836688e9084f035309E29Bf0A2095"
const soUSDC_Addr = "0xEC8FEa79026FfEd168cCf5C627c7f486D77b765F"
const soWETH_Addr = "0xf7B5965f5C117Eb1B5450187c9DcFccc3C317e8E"
const soWBTC_Addr = "0x33865E09A572d4F1CC4d75Afc9ABcc5D3d4d867D"
const wETH_Addr = "0x4200000000000000000000000000000000000006"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const COMPTROLLER_Addr = "0x60cf091cd3f50420d50fd7f707414d0df4751c58"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

const USDCPriceFeed_Addr = "0x16a9fa2fda030272ce99b29cf780dfa30361e0f3"
const ETHPriceFeed_Addr = "0x13e3ee699d1909e989722e753853ae30b17e08c5"
const BTCPriceFeed_Addr = "0xd702dd976fb76fffc2d3963d037dfdae5b04e593"

const whaleUsdcWeth_Addr = "0x33A4C0070384725DbDf57Edf3d179F6891124517"
const whaleWbtc_Addr = "0x456325F2AC7067234dD71E01bebe032B0255e039"
const whaleOp_Addr = "0x82326a9E6BD66e51a4c2c29168B10A1853Fc9Af7"

describe("Test Compound custom wrapper", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const whitelister = accounts[1]
        const backupOwner = accounts[2]
        const feeCollector = accounts[3]
        const signer = await ethers.provider.getSigner(0)
        const whaleUsdcWethSigner = await ethers.getImpersonatedSigner(whaleUsdcWeth_Addr)
        const whaleWbtcSigner = await ethers.getImpersonatedSigner(whaleWbtc_Addr)

        console.log(await helpers.time.latestBlock())

        /* Deploy CompoundV2 (Sonne) wrappers */
        const WSOUSDC = await ethers.getContractFactory("CompoundV2ERC4626Reinvest")
        const wsoUSDC = await WSOUSDC.deploy(
            USDC_Addr,
            OP_Addr,
            soUSDC_Addr,
            COMPTROLLER_Addr,
            USDCPriceFeed_Addr,
            "1000000000000000000", // amountInMin = 1 OP
            "200", // slippage = 2%
            "12" // wait = 12 seconds
        )
        await wsoUSDC.waitForDeployment()
        console.log("Deployed wsoUSDC to: ", (await wsoUSDC.getAddress()))

        const WSOETH = await ethers.getContractFactory("CompoundV2ERC4626Reinvest")
        const wsoETH = await WSOETH.deploy(
            wETH_Addr,
            OP_Addr,
            soWETH_Addr,
            COMPTROLLER_Addr,
            ETHPriceFeed_Addr,
            "1000000000000000000", // amountInMin = 1 OP
            "200", // slippage = 2%
            "12" // wait = 12 seconds
        )
        await wsoETH.waitForDeployment()
        console.log("Deployed wsoETH to: ", (await wsoETH.getAddress()))

        const WSOBTC = await ethers.getContractFactory("CompoundV2ERC4626Reinvest")
        const wsoBTC = await WSOBTC.deploy(
            wBTC_Addr,
            OP_Addr,
            soWBTC_Addr,
            COMPTROLLER_Addr,
            BTCPriceFeed_Addr,
            "1000000000000000000", // amountInMin = 1 OP
            "200", // slippage = 2%
            "12" // wait = 12 seconds
        )
        await wsoBTC.waitForDeployment()
        console.log("Deployed wsoBTC to: ", (await wsoBTC.getAddress()))

        /* Deploy COFI stablecoins */
        const FITOKEN = await ethers.getContractFactory("FiToken")
        const fiUSD = await FITOKEN.deploy(
            "COFI Dollar",
            "fiUSD"
        )
        await fiUSD.waitForDeployment()
        console.log("fiUSD deployed: " + await fiUSD.getAddress())
        const fiETH = await FITOKEN.deploy(
            "COFI Ethereum",
            "fiETH"
        )
        await fiETH.waitForDeployment()
        console.log("fiETH deployed: " + await fiETH.getAddress())
        const fiBTC = await FITOKEN.deploy(
            "COFI Ethereum",
            "fiETH"
        )
        await fiBTC.waitForDeployment()
        console.log("fiBTC deployed: " + await fiBTC.getAddress())

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
        await fiBTC.setApp(await diamond.getAddress())
        console.log("Diamond address set in fiBTC")

        await wsoUSDC.setAuthorized((await diamond.getAddress()), "1")
        await wsoETH.setAuthorized((await diamond.getAddress()), "1")
        await wsoBTC.setAuthorized((await diamond.getAddress()), "1")

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
            fiBTC:  await fiBTC.getAddress(),
            vUSDC:  await wsoUSDC.getAddress(),
            vETH:   await wsoETH.getAddress(),
            vBTC:   await wsoBTC.getAddress(),
            USDC:   USDC_Addr,
            wETH:   wETH_Addr,
            wBTC:   wBTC_Addr,
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
        const whaleUsdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(whaleUsdcWethSigner)
        await whaleUsdc.transfer((await owner.getAddress()), "1000000000") // 1,000 USDC
        console.log("Transferred USDC to user")
        const whaleWeth = (await ethers.getContractAt(wETH_ABI, wETH_Addr)).connect(whaleUsdcWethSigner)
        await whaleWeth.transfer((await owner.getAddress()), "1000000000000000000") // 1 wETH
        console.log("Transferred wETH to user")
        const whaleWbtc = (await ethers.getContractAt(wBTC_ABI, wBTC_Addr)).connect(whaleWbtcSigner)
        await whaleWbtc.transfer(await owner.getAddress(), "50000000") // 0.5 wBTC
        console.log("Transferred wBTC to user")

        /* Get asset contracts */
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        const weth = (await ethers.getContractAt(wETH_ABI, wETH_Addr)).connect(signer)
        const wbtc = (await ethers.getContractAt(wBTC_ABI, wBTC_Addr)).connect(signer)
        const soUsdc = (await ethers.getContractAt(soTOKEN_ABI, soUSDC_Addr)).connect(signer)
        const soWeth = (await ethers.getContractAt(soTOKEN_ABI, soWETH_Addr)).connect(signer)
        const soWbtc = (await ethers.getContractAt(soTOKEN_ABI, soWBTC_Addr)).connect(signer)

        /* Initial deposits */
        await usdc.approve(await diamond.getAddress(), "1000000000") // 1,000 USDC
        await cofiMoney.underlyingToFi(
            "500000000", // 500 USDC underlying [6 decimals]
            "498750000000000000000", // 0.25% slippage fi [18 decimals]
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t0 wsoUSDC Vault soUSDC bal: ", await soUsdc.balanceOf(await wsoUSDC.getAddress()))

        await weth.approve(await diamond.getAddress(), "1000000000000000000") // 1 wETH
        await cofiMoney.underlyingToFi(
            "500000000000000000", // 0.5 wETH underlying [18 decimals]
            "498750000000000000", // 0.25% slippage fi [18 decimals]
            await fiETH.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        console.log("t0 wsoETH Vault soWETH bal: ", await soWeth.balanceOf(await wsoETH.getAddress()))

        await wbtc.approve(await diamond.getAddress(), "50000000") // 0.5 wBTC
        await cofiMoney.underlyingToFi(
            "25000000", // 0.25 wBTC underlying [8 decimals]
            "24937500", // 0.25% slippage fi [18 decimals]
            await fiBTC.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User fiBTC bal: ", await fiBTC.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiBTC bal: ", await fiBTC.balanceOf(await feeCollector.getAddress()))
        console.log("t0 wsoBTC Vault soWBTC bal: ", await soWbtc.balanceOf(await wsoBTC.getAddress()))

        // Set up executable harvest
        const whaleOpSigner = await ethers.getImpersonatedSigner(whaleOp_Addr)
        const whaleOp = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(whaleOpSigner)
        await whaleOp.transfer(await wsoUSDC.getAddress(), "100000000000000000000") // 100 OP
        console.log("Transferred OP to wsoUSDC contract")
        await whaleOp.transfer(await wsoETH.getAddress(), "100000000000000000000") // 100 OP
        console.log("Transferred OP to wsoETH contract")
        await whaleOp.transfer(await wsoBTC.getAddress(), "100000000000000000000") // 100 OP
        console.log("Transferred OP to wsoBTC contract")

        // Test recoverERC20()
        await wsoUSDC.recoverERC20(OP_Addr, "0")
        console.log("Recovered: ", await whaleOp.balanceOf(await owner.getAddress()))

        // Set swap routes
        await wsoUSDC.setRoute("3000", wETH_Addr, "500")
        await wsoETH.setRoute("3000", wETH_Addr, "0")
        await wsoBTC.setRoute("3000", wETH_Addr, "3000")
        console.log("Set routes")

        return {
            owner, whaleUsdc, whaleWeth, whaleWbtc, fiUSD, fiETH, fiBTC, wsoUSDC, wsoETH, wsoBTC, feeCollector,
            soUsdc, soWeth, soWbtc, cofiMoney, usdc, weth, wbtc, WSOUSDC
        }
    }

    it("Should rebase manually (harvesting with swap) and redeem fiUSD", async function() {

        const { owner, fiUSD, feeCollector, cofiMoney, usdc, soUsdc, wsoUSDC } = await loadFixture(deploy)

        /* Rebase */
        await cofiMoney.rebase(await fiUSD.getAddress())

        console.log("t1 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        // Should increase
        console.log("t1 wsoUSDC Vault soUSDC bal: ", await soUsdc.balanceOf(await wsoUSDC.getAddress()))
        
        await fiUSD.approve(await cofiMoney.getAddress(), await fiUSD.balanceOf(await owner.getAddress()))
        await cofiMoney.fiToUnderlying(
            await fiUSD.balanceOf(await owner.getAddress()),
            "0",
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress()
        )

        console.log("t2 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t2 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        // Should deplete
        console.log("t2 wsoUSDC Vault soUSDC bal: ", await soUsdc.balanceOf(await wsoUSDC.getAddress()))
        console.log('t2 User USDC bal: ', await usdc.balanceOf(await owner.getAddress()))
    })

    it("Should rebase manually (harvesting with swap) and redeem fiETH", async function() {

        const { owner, fiETH, feeCollector, cofiMoney, weth, soWeth, wsoETH } = await loadFixture(deploy)

        /* Rebase */
        await cofiMoney.rebase(await fiETH.getAddress())

        console.log("t1 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        // Should increase
        console.log("t1 wsoETH Vault soWETH bal: ", await soWeth.balanceOf(await wsoETH.getAddress()))
        
        await fiETH.approve(await cofiMoney.getAddress(), await fiETH.balanceOf(await owner.getAddress()))
        await cofiMoney.fiToUnderlying(
            await fiETH.balanceOf(await owner.getAddress()),
            "0",
            await fiETH.getAddress(),
            await owner.getAddress(),
            await owner.getAddress()
        )

        console.log("t2 User fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        console.log("t2 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        // Should deplete
        console.log("t2 wsoETH Vault soWETH bal: ", await soWeth.balanceOf(await wsoETH.getAddress()))
        console.log('t2 User wETH bal: ', await weth.balanceOf(await owner.getAddress()))
    })

    it("Should rebase manually (harvesting with swap) and redeem fiBTC", async function() {

        const { owner, fiBTC, feeCollector, cofiMoney, wbtc, soWbtc, wsoBTC } = await loadFixture(deploy)

        /* Rebase */
        await cofiMoney.rebase(await fiBTC.getAddress())

        console.log("t1 User fiBTC bal: ", await fiBTC.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector fiBTC bal: ", await fiBTC.balanceOf(await feeCollector.getAddress()))
        // Should increase
        console.log("t1 wsoBTC Vault soWBTC bal: ", await soWbtc.balanceOf(await wsoBTC.getAddress()))
        
        await fiBTC.approve(await cofiMoney.getAddress(), await fiBTC.balanceOf(await owner.getAddress()))
        await cofiMoney.fiToUnderlying(
            await fiBTC.balanceOf(await owner.getAddress()),
            "0",
            await fiBTC.getAddress(),
            await owner.getAddress(),
            await owner.getAddress()
        )

        console.log("t2 User fiBTC bal: ", await fiBTC.balanceOf(await owner.getAddress()))
        console.log("t2 Fee Collector fiBTC bal: ", await fiBTC.balanceOf(await feeCollector.getAddress()))
        // Should deplete
        console.log("t2 wsoBTC Vault soWBTC bal: ", await soWbtc.balanceOf(await wsoBTC.getAddress()))
        console.log('t2 User wBTC bal: ', await wbtc.balanceOf(await owner.getAddress()))
    })

    it("Should migrate fiUSD", async function() {

        const { owner, fiUSD, feeCollector, cofiMoney, usdc, soUsdc, wsoUSDC, WSOUSDC, whaleUsdc } = await loadFixture(deploy)

        /* Rebase */
        await cofiMoney.rebase(await fiUSD.getAddress())

        console.log("t1 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        // Should increase
        console.log("t1 wsoUSDC Vault soUSDC bal: ", await soUsdc.balanceOf(await wsoUSDC.getAddress()))

        /* Migration */
        // First deploy Compound (Sonne) vault
        const _wsoUSDC = await WSOUSDC.deploy(
            USDC_Addr,
            OP_Addr,
            soUSDC_Addr,
            COMPTROLLER_Addr,
            USDCPriceFeed_Addr,
            "1000000000000000000", // amountInMin = 1 OP
            "200", // slippage = 2%
            "12" // wait = 12 seconds
        )
        await wsoUSDC.waitForDeployment()
        console.log("Deployed _wsoUSDC to: ", (await wsoUSDC.getAddress()))
        await _wsoUSDC.setAuthorized(await cofiMoney.getAddress(), "1")
        // Transfer 2x USDC buffer to Diamond
        whaleUsdc.transfer(await cofiMoney.getAddress(), "200000000")
        // Migrate
        await cofiMoney.migrate(await fiUSD.getAddress(), await _wsoUSDC.getAddress())

        console.log("t2 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t2 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        // Should deplete
        console.log("t2 wsoUSDC Vault soUSDC bal: ", await soUsdc.balanceOf(await wsoUSDC.getAddress()))
        console.log("t2 Diamond wsoUSDC bal: ", await wsoUSDC.balanceOf(await cofiMoney.getAddress()))
        // Should have new balance
        console.log("t2 _wsoUSDC Vault soUSDC bal: ", await soUsdc.balanceOf(await _wsoUSDC.getAddress()))
        console.log("t2 Diamond _wsoUSDC bal: ", await _wsoUSDC.balanceOf(await cofiMoney.getAddress()))
        
        await fiUSD.approve(await cofiMoney.getAddress(), await fiUSD.balanceOf(await owner.getAddress()))
        await cofiMoney.fiToUnderlying(
            await fiUSD.balanceOf(await owner.getAddress()),
            "0",
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress()
        )

        console.log("t3 User fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t3 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))
        // Should deplete
        console.log("t3 _wsoUSDC Vault soUSDC bal: ", await soUsdc.balanceOf(await _wsoUSDC.getAddress()))
        console.log('t3 User USDC bal: ', await usdc.balanceOf(await owner.getAddress()))
    })

    // it("Should harvest with swap, rebase, and redeem fiUSD", async function() {

    //     // wsoBTC => sowBTC => wBTC
    //     const { owner, wsoBTC, sowBTC, wbtc } = await loadFixture(deploy)

    //     /* Harvest */
    //     await wsoBTC.harvest()

    //     // wsoBTC balance is unchanged
    //     const t1_wsoBTCBal = await wsoBTC.balanceOf(await owner.getAddress())
    //     // Preview how much wBTC Owner should redeem
    //     const t1_wbtcBal = await wsoBTC.previewRedeem(t1_wsoBTCBal.toString())
        
    //     // Post-harvest balance
    //     console.log("t1 Owner wsoBTC bal: " + t1_wsoBTCBal.toString())
    //     console.log("t1 Owner wBTC bal: " + t1_wbtcBal.toString())

    //     await wsoBTC.redeem("25000000", owner.getAddress(), owner.getAddress())

    //     const t2_wbtcBal = await wbtc.balanceOf(owner.getAddress())
    //     console.log("t2 Owner wBTC bal: " + t2_wbtcBal.toString())
    // })

    // it("Should harvest with swap disabled and redeem", async function() {

    //     // wsoBTC => sowBTC => wBTC
    //     const { owner, wsoBTC, sowBTC, wbtc, _wbtc } = await loadFixture(deploy)

    //     // Disable swap route
    //     await wsoBTC.setEnabled("0")
    
    //     _wbtc.transfer(wsoBTC.getAddress(), "10000000") // 0.1 wBTC
    //     const t1_wrapperWbtcBal = await wbtc.balanceOf(wsoBTC.getAddress())
    //     console.log("t1 Wrapper wBTC bal: " + t1_wrapperWbtcBal.toString())
    //     // For some reason this contract instance only shows the bal increase
    //     // despite both instances referring to the same contract.
    //     const t1_wrapperWbtcBal_ = await _wbtc.balanceOf(wsoBTC.getAddress())
    //     console.log("t1 Wrapper wBTC bal: " + t1_wrapperWbtcBal_.toString())

    //     /* Harvest */
    //     await wsoBTC.harvest()
    //     const t2_wrapperWbtcBal = await wbtc.balanceOf(wsoBTC.getAddress())
    //     console.log("t2 Wrapper wBTC bal: " + t2_wrapperWbtcBal.toString())

    //     // wsoBTC balance is unchanged
    //     const t2_wsoBTCBal = await wsoBTC.balanceOf(await owner.getAddress())
    //     // Preview how much wBTC Owner should redeem
    //     const t2_wbtcBal = await wsoBTC.previewRedeem(t2_wsoBTCBal.toString())
        
    //     // Post-harvest balance
    //     console.log("t2 Owner wsoBTC bal: " + t2_wsoBTCBal.toString())
    //     console.log("t2 Owner wBTC bal: " + t2_wbtcBal.toString())

    //     await wsoBTC.redeem("25000000", owner.getAddress(), owner.getAddress())

    //     const t3_wbtcBal = await wbtc.balanceOf(owner.getAddress())
    //     console.log("t3 Owner wBTC bal: " + t3_wbtcBal.toString())
    // })

    // it("Should prevent unauthorized access", async function() {

    //     const { owner, wsoBTC, sowBTC, wbtc, _wbtc, whaleBtcSigner } = await loadFixture(deploy)

    //     await _wbtc.approve(await wsoBTC.getAddress(), "10000000") // 0.1 wBTC

    //     const _wsoBTC = wsoBTC.connect(whaleBtcSigner)

    //     // Try to set admin
    //     // await _wsoBTC.setAdmin(whaleBtc, "1")
    //     // console.log("Whale Admin status: " (await _wsoBTC.admin(whaleBtc)).toString())

    //     // Deposit should fail
    //     _wsoBTC.deposit("10000000", whaleBtc)

    //     const t1_wbtcBal = await _wbtc.balanceOf(whaleBtc)
    //     // wsoBTC balance is unchanged
    //     const t1_wsoBTCBal = await _wsoBTC.balanceOf(whaleBtc)
    //     // Preview how much wBTC Owner should redeem
    //     const t1_wbtcBalPR = await _wsoBTC.previewRedeem(t1_wsoBTCBal.toString())
        
    //     // Post-deposit balance
    //     console.log("t1 Whale wBTC bal: " + t1_wbtcBal.toString())
    //     console.log("t1 Whale wsoBTC bal: " + t1_wsoBTCBal.toString())
    //     // previewRedeem
    //     console.log("t1 Whale wBTC bal PR: " + t1_wbtcBalPR.toString())       
        
    //     // Now set authorizedEnabled to 0.
    //     await wsoBTC.setAuthorizedEnabled("0")

    //     // And try again - deposit should work
    //     _wsoBTC.deposit("10000000", whaleBtc)

    //     const t2_wbtcBal = await _wbtc.balanceOf(whaleBtc)
    //     const _t2_wbtcBal = await wbtc.balanceOf(whaleBtc)
    //     // wsoBTC balance is unchanged
    //     const t2_wsoBTCBal = await _wsoBTC.balanceOf(whaleBtc)
    //     // Preview how much wBTC Owner should redeem
    //     const t2_wbtcBalPR = await _wsoBTC.previewRedeem(t2_wsoBTCBal.toString())
        
    //     // Post-deposit balance
    //     console.log("t2 Whale wBTC bal: " + t2_wbtcBal.toString())
    //     console.log("t2 Whale wBTC bal: " + _t2_wbtcBal.toString())
    //     console.log("t2 Whale wsoBTC bal: " + t2_wsoBTCBal.toString())
    //     // previewRedeem
    //     console.log("t2 Whale wBTC bal PR: " + t2_wbtcBalPR.toString())  
    // })
})