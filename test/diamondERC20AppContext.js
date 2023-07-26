/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
// const WETH_ABI = require("./abi/WETH.json")
const OP_ABI = require("./abi/OP.json")
// const YVUSDC_ABI = require("./abi/YVUSDC.json")
// const YVETH_ABI = require("./abi/YVETH.json")
// const WBTC_ABI = require("./abi/WBTC.json")
// const SOWBTC_ABI = require("./abi/SOWBTC.json")
const FIUSD_ABI = require("./abi/COFIToken.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
// const WETH_Addr = "0x4200000000000000000000000000000000000006"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const YVUSDC_Addr = "0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2"
// const YVETH_Addr = "0x5B977577Eb8a480f63e11FC615D6753adB8652Ae"
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const StakingRewards_YVUSDC_Addr = "0xB2c04C55979B6CA7EB10e666933DE5ED84E6876b"
// const StakingRewards_YVETH_Addr = "0xE35Fec3895Dcecc7d2a91e8ae4fF3c0d43ebfFE0"
// const WBTC_Addr = "0x68f180fcCe6836688e9084f035309E29Bf0A2095"
// const SOWBTC_Addr = "0x33865E09A572d4F1CC4d75Afc9ABcc5D3d4d867D"
// const COMPTROLLER_Addr = "0x60cf091cd3f50420d50fd7f707414d0df4751c58"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

/* Yearn Swap Params */

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "200" // 2%
const wait = "12" // 12 seconds
const poolFee = "3000" // 0.3%

const whaleUsdcEth = "0xee55c2100C3828875E0D65194311B8eF0372C6d9"
// const whaleBtc = "0x456325F2AC7067234dD71E01bebe032B0255e039"
const whaleOp = "0x82326a9E6BD66e51a4c2c29168B10A1853Fc9Af7"

// Note actual deployment may have to be partitioned into smaller steps

describe("Test wrappers in app context", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const backupOwner = accounts[1]
        const whitelister = accounts[2]
        const feeCollector = accounts[3]

        const signer = (await ethers.provider.getSigner(0))
        const wueSigner = (await ethers.getImpersonatedSigner(whaleUsdcEth))
        const wopSigner = (await ethers.getImpersonatedSigner(whaleOp))

        console.log(await helpers.time.latestBlock())

        /* Deploy wrappers */

        const WYVUSDC = await ethers.getContractFactory("YearnV2ERC4626Wrapper")
        const wyvUSDC = await WYVUSDC.deploy(
            YVUSDC_Addr,
            YVOP_Addr,
            StakingRewards_YVUSDC_Addr,
            "0x0000000000000000000000000000000000000000",
            USDC_Addr, // want
            getRewardMin,
            amountInMin,
            slippage,
            wait,
            poolFee,
            {gasLimit: "30000000"}
        )
        await wyvUSDC.waitForDeployment()
        console.log("wyvUSDC deployed: ", await wyvUSDC.getAddress())
    
        // const WYVETH = await ethers.getContractFactory("YearnV2ERC4626Wrapper")
        // const wyvETH = await WYVETH.deploy(
        //     YVETH_Addr,
        //     YVOP_Addr,
        //     StakingRewards_YVETH_Addr,
        //     "0x13e3Ee699D1909E989722E753853AE30b17e08c5", // ETH price feed
        //     WETH_Addr,
        //     getRewardMin,
        //     amountInMin,
        //     slippage,
        //     wait,
        //     poolFee,
        //     {gasLimit: "30000000"}
        // )
        // await wyvETH.waitForDeployment()
        // console.log("wyvETH deployed: ", await wyvETH.getAddress())

        // const WSOBTC = await ethers.getContractFactory("CompoundV2ERC4626Wrapper")
        // const wsoBTC = await WSOBTC.deploy(
        //     WBTC_Addr,
        //     OP_Addr,
        //     SOWBTC_Addr,
        //     COMPTROLLER_Addr,
        //     "0xd702dd976fb76fffc2d3963d037dfdae5b04e593", // BTC price feed
        //     "1000000000000000000", // amountInMin = 1 OP
        //     "200", // slippage = 2%
        //     "12" // wait = 12 seconds
        // )
        // await wsoBTC.waitForDeployment()
        // console.log("wsoBTC deployed: ", await wsoBTC.getAddress())
        // await wsoBTC.setRoute("3000", WETH_Addr, "3000")

        // const FIUSD = await ethers.getContractFactory("FiToken")
        // const fiUSD = await FIUSD.deploy(
        //     "COFI Dollar",
        //     "fiUSD"
        // )
        // await fiUSD.waitForDeployment()
        // console.log("fiUSD deployed: " + await fiUSD.getAddress())

        // Deploy DiamondCutFacet
        const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet")
        const diamondCutFacet = await DiamondCutFacet.deploy()
        await diamondCutFacet.waitForDeployment()
        console.log("DiamondCutFacet deployed: ", await diamondCutFacet.getAddress())

        // Deploy fiUSD Diamond
        const ERC20Diamond = await ethers.getContractFactory("Diamond")
        const erc20Diamond = await ERC20Diamond.deploy(
            await owner.getAddress(),
            await diamondCutFacet.getAddress()
        )
        await erc20Diamond.waitForDeployment()
        console.log("ERC20Diamond deployed: ", await erc20Diamond.getAddress())
        
        // Deploy App Diamond
        const Diamond = await ethers.getContractFactory("Diamond")
        const diamond = await Diamond.deploy(
            await owner.getAddress(),
            await diamondCutFacet.getAddress()
        )
        await diamond.waitForDeployment()
        console.log("Diamond deployed: ", await diamond.getAddress())

        // Set Diamond address in FiToken contract.
        // await fiUSD.setDiamond(await diamond.getAddress())
        // console.log("Diamond address set in fiUSD")

        /* Token Diamond */
        // Deploy DiamondInit
        // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
        // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
        const ERC20DiamondInit = await ethers.getContractFactory('ERC20InitDiamond')
        const erc20DiamondInit = await ERC20DiamondInit.deploy()
        await erc20DiamondInit.waitForDeployment()
        console.log('ERC20DiamondInit deployed:', await erc20DiamondInit.getAddress())

        // Deploy facets
        console.log('')
        console.log('Deploying facets')
        const ERC20FacetNames = [
        'DiamondLoupeFacet',
        'OwnershipFacet',
        'TokenAccessFacet',
        'TokenERC20Facet',
        'TokenRebaseFacet'
        ]
        const erc20Cut = []
        for (const ERC20FacetName of ERC20FacetNames) {
            const ERC20Facet = await ethers.getContractFactory(ERC20FacetName)
            const erc20Facet = await ERC20Facet.deploy()
            await erc20Facet.waitForDeployment()
            console.log(`${ERC20FacetName} deployed: ${await erc20Facet.getAddress()}`)
            erc20Cut.push({
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: getSelectors(erc20Facet)
            })
        }
       
        const erc20InitArgs = [{
            name:   "COFI Dollar",
            symbol: "fiUSD",
            app:    await diamond.getAddress(),
            roles: [
                await owner.getAddress(),
                await backupOwner.getAddress(),
            ]
        }]
        
        // Upgrade diamond with facets
        console.log('')
        console.log('ERC20 Diamond Cut:', erc20Cut)
        const erc20DiamondCut = await ethers.getContractAt('IDiamondCut', await erc20Diamond.getAddress())
        let erc20Tx
        let erc20Receipt
        // Call to init function
        let erc20FunctionCall = erc20DiamondInit.interface.encodeFunctionData('init', erc20InitArgs)
        erc20Tx = await erc20DiamondCut.diamondCut(erc20Cut, await erc20DiamondInit.getAddress(), erc20FunctionCall)
        console.log('ERC20 Diamond cut tx: ', erc20Tx.hash)
        erc20Receipt = await erc20Tx.wait()
        if (!erc20Receipt.status) {
        throw Error(`ERC20 Diamond upgrade failed: ${erc20Tx.hash}`)
        }
        console.log('Completed ERC20 diamond cut')

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
            fiUSD:  await erc20Diamond.getAddress(),
            // fiETH:  (await fiETH.getAddress()),
            // fiBTC:  (await fiBTC.getAddress()),
            vUSDC:  await wyvUSDC.getAddress(),
            // vETH:   (await wyvETH.getAddress()),
            // vBTC:   (await wsoBTC.getAddress()),
            USDC:   USDC_Addr,
            // wETH:   WETH_Addr,
            // wBTC:   WBTC_Addr,
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

        // Authorize Diamond to interact with wrappers
        await wyvUSDC.setAuthorized(await diamond.getAddress(), "1")
        // await wyvETH.setAuthorized(await diamond.getAddress(), "1")
        // await wsoBTC.setAuthorized(await diamond.getAddress(), "1")
        console.log("Authorized Diamond interaction with wrapper")

        /* Whitelist user */
        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)
        await cofiMoney.setWhitelist((await owner.getAddress()), "1")
        console.log("Whitelisted user")

        /* Transfer user assets */
        const wue_usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(wueSigner)
        await wue_usdc.transfer((await owner.getAddress()), "1000000000") // 1,000 USDC
        console.log("Transferred USDC to user")

        /* Initial deposits */
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        await usdc.approve(await diamond.getAddress(), "1000000000") // 1,000 USDC
        const fiUSD = (await ethers.getContractAt(FIUSD_ABI, await erc20Diamond.getAddress())).connect(signer)
        await cofiMoney.underlyingToFi(
            "1000000000",
            "997500000", // 0.25% slippage
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 Owner fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))

        /* Set up executable yield distribution */
        const wop_op = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(wopSigner)
        await wop_op.transfer(await wyvUSDC.getAddress(), "10000000000000000000") // 10 OP
        console.log("Transferred OP to wrapper")

        return {
            owner, feeCollector, signer, wueSigner, wyvUSDC, fiUSD, usdc, cofiMoney
        }
    }

    it("Should transfer", async function() {

        const { owner, backupOwner, fiUSD } = await loadFixture(deploy)

        await fiUSD.transfer((await backupOwner.getAddress()), "9000000000000000000000")

        console.log("Receiver fiUSD bal: " + await fiUSD.balanceOf(await backupOwner.getAddress()))
    })

    it("Should harvest, rebase for fiUSD, and redeem", async function() {

        const { owner, feeCollector, wyvUSDC, fiUSD, usdc, cofiMoney } = await loadFixture(deploy)

        // Harvest
        await cofiMoney.rebase(await fiUSD.getAddress())

        console.log("t1 Owner fiUSD bal: " + (await fiUSD.balanceOf(await owner.getAddress())))
        console.log("t1 Fee Collector fiUSD bal: " + (await fiUSD.balanceOf(await feeCollector.getAddress())))
        console.log("t1 Diamond wyvUSDC bal: " + (await wyvUSDC.balanceOf(await cofiMoney.getAddress())))

        // Redeem
        await cofiMoney.fiToUnderlying(
            await fiUSD.balanceOf(await owner.getAddress()),
            "1000000000", // Compare to actual amount received
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress()
        )

        console.log("t2 Owner USDC bal: " + (await usdc.balanceOf(await owner.getAddress())))
        console.log("t2 Owner fiUSD bal: " + (await fiUSD.balanceOf(await owner.getAddress())))
        console.log("t2 Fee Collector fiUSD bal: " + (await fiUSD.balanceOf(await feeCollector.getAddress())))
        console.log("t2 Diamond wyvUSDC bal: " + (await wyvUSDC.balanceOf(await cofiMoney.getAddress())))
    })
})