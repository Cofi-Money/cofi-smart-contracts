/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const WETH_ABI = require("./abi/WETH.json")
const OP_ABI = require("./abi/OP.json")
const YVUSDC_ABI = require("./abi/YVUSDC.json")
const YVETH_ABI = require("./abi/YVETH.json")

const WBTC_ABI = require("./abi/WBTC.json")
const SOWBTC_ABI = require("./abi/SOWBTC.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const WETH_Addr = "0x4200000000000000000000000000000000000006"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const YVUSDC_Addr = "0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2"
const YVETH_Addr = "0x5B977577Eb8a480f63e11FC615D6753adB8652Ae"
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const StakingRewards_YVUSDC_Addr = "0xB2c04C55979B6CA7EB10e666933DE5ED84E6876b"
const StakingRewards_YVETH_Addr = "0xE35Fec3895Dcecc7d2a91e8ae4fF3c0d43ebfFE0"

const WBTC_Addr = "0x68f180fcCe6836688e9084f035309E29Bf0A2095"
const SOWBTC_Addr = "0x33865E09A572d4F1CC4d75Afc9ABcc5D3d4d867D"
const COMPTROLLER_Addr = "0x60cf091cd3f50420d50fd7f707414d0df4751c58"

const NULL_Addr = "0x0000000000000000000000000000000000000000"

/* Yearn Swap Params */

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "200" // 2%
const wait = "12" // 12 seconds
const poolFee = "3000" // 0.3%

const whaleUsdcEth = "0xee55c2100C3828875E0D65194311B8eF0372C6d9"
const whaleBtc = "0x456325F2AC7067234dD71E01bebe032B0255e039"
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
        const wbtSigner = (await ethers.getImpersonatedSigner(whaleBtc))
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

        /* Deploy COFI tokens */

        const FIUSD = await ethers.getContractFactory("FiToken")
        const fiUSD = await FIUSD.deploy(
            "COFI Dollar",
            "fiUSD"
        )
        await fiUSD.waitForDeployment()
        console.log("fiUSD deployed: " + await fiUSD.getAddress())

        // const FIETH = await ethers.getContractFactory("FiToken")
        // const fiETH = await FIETH.deploy(
        //     "COFI Ethereum",
        //     "fiETH"
        // )
        // await fiETH.waitForDeployment()
        // console.log("fiETH deployed: " + await fiETH.getAddress())

        // const FIBTC = await ethers.getContractFactory("FiToken")
        // const fiBTC = await FIBTC.deploy(
        //     "COFI Bitcoin",
        //     "fiBTC"
        // )
        // await fiBTC.waitForDeployment()
        // console.log("fiBTC deployed: " + await fiBTC.getAddress())

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
        // await fiETH.setDiamond(await diamond.getAddress())
        // console.log("Diamond address set in fiETH")
        // await fiBTC.setDiamond(await diamond.getAddress())
        // console.log("Diamond address set in fiBTC")

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
            fiUSD:  (await fiUSD.getAddress()),
            // fiETH:  (await fiETH.getAddress()),
            // fiBTC:  (await fiBTC.getAddress()),
            vUSDC:  (await wyvUSDC.getAddress()),
            // vETH:   (await wyvETH.getAddress()),
            // vBTC:   (await wsoBTC.getAddress()),
            USDC:   USDC_Addr,
            // wETH:   WETH_Addr,
            // wBTC:   WBTC_Addr,
            roles: [
                (await whitelister.getAddress()),
                (await backupOwner.getAddress()),
                (await feeCollector.getAddress())
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
        console.log("Authorized Diamond interaction with wrappers")

        // Deploy Point Token contract
        const Point = await ethers.getContractFactory('PointToken')
        const point = await Point.deploy(
            "COFI Point",
            "COFI",
            await diamond.getAddress(),
            [
                await fiUSD.getAddress()
                // await fiETH.getAddress(),
                // await fiBTC.getAddress()
            ]
        )
        await point.waitForDeployment()
        console.log('Point token deployed: ', await point.getAddress())

        /* Whitelist user */
        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)
        await cofiMoney.setWhitelist((await owner.getAddress()), "1")
        console.log("Whitelisted user")

        /* Transfer user assets */
        const wue_usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(wueSigner)
        await wue_usdc.transfer((await owner.getAddress()), "1000000000") // 1,000 USDC
        console.log("Transferred USDC to user")
        // const wue_eth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(wueSigner)
        // await wue_eth.transfer((await owner.getAddress()), "500000000000000000") // 0.5 wETH
        // console.log("Transferred wETH to user")
        // const wbt_btc = (await ethers.getContractAt(WBTC_ABI, WBTC_Addr)).connect(wbtSigner)
        // await wbt_btc.transfer((await owner.getAddress()), "10000000") // 0.1 wBTC
        // console.log("Transferred wBTC to user")

        /* Migration test - transfer buffer */
        await wue_usdc.transfer((await diamond.getAddress()), "100000000") // 100 USDC
        // await wue_eth.transfer((await diamond.getAddress()), "100000000000000000") // 0.1 wETH
        // await wbt_btc.transfer((await diamond.getAddress()), "1000000") // 0.01 wBTC

        /* Initial deposits */
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        await usdc.approve(await diamond.getAddress(), "1000000000") // 1,000 USDC
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
        // const weth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(signer)
        // await weth.approve(await diamond.getAddress(), "500000000000000000") // 0.5 wETH
        // await cofiMoney.underlyingToFi(
        //     "500000000000000000",
        //     "498750000000000000", // 0.25% slippage
        //     await fiETH.getAddress(),
        //     await owner.getAddress(),
        //     await owner.getAddress(),
        //     NULL_Addr
        // )
        // console.log("t0 Owner fiETH bal: ", await fiETH.balanceOf(await owner.getAddress()))
        // console.log("t0 Fee Collector fiETH bal: ", await fiETH.balanceOf(await feeCollector.getAddress()))
        // const wbtc = (await ethers.getContractAt(WBTC_ABI, WBTC_Addr)).connect(signer)
        // await wbtc.approve(await diamond.getAddress(), "10000000") // 0.1 wBTC
        // await cofiMoney.underlyingToFi(
        //     "10000000",
        //     "99750000", // 0.25% slippage
        //     await fiBTC.getAddress(),
        //     await owner.getAddress(),
        //     await owner.getAddress(),
        //     NULL_Addr
        // )
        // console.log("t0 Owner fiBTC bal: ", await fiBTC.balanceOf(await owner.getAddress()))
        // console.log("t0 Fee Collector fiBTC bal: ", await fiBTC.balanceOf(await feeCollector.getAddress()))

        console.log("t0 points: " + await point.balanceOf(await owner.getAddress()))

        /* Set up executable yield distribution */
        const wop_op = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(wopSigner)
        await wop_op.transfer(await wyvUSDC.getAddress(), "10000000000000000000") // 10 OP
        // await wop_op.transfer(await wyvETH.getAddress(), "10000000000000000000") // 10 OP
        // await wop_op.transfer(await wsoBTC.getAddress(), "10000000000000000000") // 10 OP
        console.log("Transferred OP to wrappers")

        /* Migration test - do a rebase beforehand to better simulate in live env */
        await cofiMoney.rebase(await fiUSD.getAddress())
        // await cofiMoney.rebase(await fiETH.getAddress())
        // await cofiMoney.rebase(await fiBTC.getAddress())

        return {
            owner, feeCollector, signer, wueSigner,
            // wbtSigner,
            wyvUSDC,
            // wyvETH, wsoBTC,
            fiUSD,
            // fiETH, fiBTC,
            usdc,
            // weth, wbtc,
            cofiMoney, point
        }
    }

    // it("Should harvest, rebase for fiUSD, and redeem", async function() {

    //     const { owner, feeCollector, wyvUSDC, fiUSD, usdc, cofiMoney, point } = await loadFixture(deploy)

    //     // Harvest
    //     await cofiMoney.rebase(await fiUSD.getAddress())

    //     console.log("t1 Owner fiUSD bal: " + (await fiUSD.balanceOf(await owner.getAddress())))
    //     console.log("t1 Fee Collector fiUSD bal: " + (await fiUSD.balanceOf(await feeCollector.getAddress())))
    //     console.log("t1 Diamond wyvUSDC bal: " + (await wyvUSDC.balanceOf(await cofiMoney.getAddress())))
    //     console.log("t1 points: " + await point.balanceOf(await owner.getAddress()))

    //     // Redeem
    //     await cofiMoney.fiToUnderlying(
    //         await fiUSD.balanceOf(await owner.getAddress()),
    //         "1000000000", // Compare to actual amount received
    //         await fiUSD.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress()
    //     )

    //     console.log("t2 Owner USDC bal: " + (await usdc.balanceOf(await owner.getAddress())))
    //     console.log("t2 Owner fiUSD bal: " + (await fiUSD.balanceOf(await owner.getAddress())))
    //     console.log("t2 Fee Collector fiUSD bal: " + (await fiUSD.balanceOf(await feeCollector.getAddress())))
    //     console.log("t2 Diamond wyvUSDC bal: " + (await wyvUSDC.balanceOf(await cofiMoney.getAddress())))
    //     console.log("t2 points: " + await point.balanceOf(await owner.getAddress()))
    // })

    // it("Should harvest, rebase for fiETH, and redeem", async function() {

    //     const { owner, feeCollector, wyvETH, fiETH, weth, cofiMoney, point } = await loadFixture(deploy)

    //     // Harvest
    //     await cofiMoney.rebase(await fiETH.getAddress())

    //     console.log("t1 Owner fiETH bal: " + (await fiETH.balanceOf(await owner.getAddress())))
    //     console.log("t1 Fee Collector fiETH bal: " + (await fiETH.balanceOf(await feeCollector.getAddress())))
    //     console.log("t1 Diamond wyvETH bal: " + (await wyvETH.balanceOf(await cofiMoney.getAddress())))
    //     console.log("t1 points: " + await point.balanceOf(await owner.getAddress()))

    //     // Redeem
    //     await cofiMoney.fiToUnderlying(
    //         await fiETH.balanceOf(await owner.getAddress()),
    //         "500000000000000000", // Compare to actual amount received
    //         await fiETH.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress()
    //     )

    //     console.log("t2 Owner wETH bal: " + (await weth.balanceOf(await owner.getAddress())))
    //     console.log("t2 Owner fiETH bal: " + (await fiETH.balanceOf(await owner.getAddress())))
    //     console.log("t2 Fee Collector fiETH bal: " + (await fiETH.balanceOf(await feeCollector.getAddress())))
    //     console.log("t2 Diamond wyvETH bal: " + (await wyvETH.balanceOf(await cofiMoney.getAddress())))
    //     console.log("t2 points: " + await point.balanceOf(await owner.getAddress()))
    // })

    // it("Should harvest, rebase for fiBTC, and redeem", async function() {

    //     const { owner, feeCollector, wsoBTC, fiBTC, wbtc, cofiMoney, point } = await loadFixture(deploy)

    //     // Harvest
    //     await cofiMoney.rebase(await fiBTC.getAddress())

    //     console.log("t1 Owner fiBTC bal: " + (await fiBTC.balanceOf(await owner.getAddress())))
    //     console.log("t1 Fee Collector fiBTC bal: " + (await fiBTC.balanceOf(await feeCollector.getAddress())))
    //     console.log("t1 Diamond wsoBTC bal: " + (await wsoBTC.balanceOf(await cofiMoney.getAddress())))
    //     console.log("t1 points: " + await point.balanceOf(await owner.getAddress()))

    //     // Redeem
    //     await cofiMoney.fiToUnderlying(
    //         await fiBTC.balanceOf(await owner.getAddress()),
    //         "10000000", // Compare to actual amount received
    //         await fiBTC.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress()
    //     )

    //     console.log("t2 Owner wBTC bal: " + (await wbtc.balanceOf(await owner.getAddress())))
    //     console.log("t2 Owner fiBTC bal: " + (await fiBTC.balanceOf(await owner.getAddress())))
    //     console.log("t2 Fee Collector fiBTC bal: " + (await fiBTC.balanceOf(await feeCollector.getAddress())))
    //     console.log("t2 Diamond wsoBTC bal: " + (await wsoBTC.balanceOf(await cofiMoney.getAddress())))
    //     console.log("t2 points: " + await point.balanceOf(await owner.getAddress()))
    // })

    it("Should migrate", async function() {

        const Vault = await ethers.getContractFactory('Vault')
        const vusdc = await Vault.deploy('Vault USDC', 'vUSDC', USDC_Addr)
        await vusdc.waitForDeployment()

        // const veth = await Vault.deploy('Vault wETH', 'vETH', WETH_Addr)
        // await veth.waitForDeployment()

        // const vbtc = await Vault.deploy('Vault BTC', 'vBTC', WBTC_Addr)
        // await vbtc.waitForDeployment()

        // Includes rebase
        const {
            owner, feeCollector, usdc,
            // weth, wbtc,
            fiUSD,
            // fiETH, fiBTC,
            cofiMoney
        } = await loadFixture(deploy)

        console.log('t1 fiUSD total supply: ' + await fiUSD.totalSupply())
        // console.log('t1 fiETH total supply: ' + await fiETH.totalSupply())
        // console.log('t1 fiBTC total supply: ' + await fiBTC.totalSupply())
        console.log('t1 Owner fiUSD bal: ' + await fiUSD.balanceOf(await owner.getAddress()))
        // console.log('t1 Owner fiETH bal: ' + await fiETH.balanceOf(await owner.getAddress()))
        // console.log('t1 Owner fiBTC bal: ' + await fiBTC.balanceOf(await owner.getAddress()))

        await cofiMoney.migrateVault(await fiUSD.getAddress(), await vusdc.getAddress())
        // await cofiMoney.migrateVault(await fiETH.getAddress(), await veth.getAddress())
        // await cofiMoney.migrateVault(await fiBTC.getAddress(), await vbtc.getAddress())

        console.log('t2 fiUSD total supply: ' + await fiUSD.totalSupply())
        // console.log('t2 fiETH total supply: ' + await fiETH.totalSupply())
        // console.log('t2 fiBTC total supply: ' + await fiBTC.totalSupply())
        console.log('t2 Owner fiUSD bal: ' + await fiUSD.balanceOf(await owner.getAddress()))
        // console.log('t2 Owner fiETH bal: ' + await fiETH.balanceOf(await owner.getAddress()))
        // console.log('t2 Owner fiBTC bal: ' + await fiBTC.balanceOf(await owner.getAddress()))

        // Check the new vault address in Diamond
        console.log('fiUSD vault: ' + await cofiMoney.getVault(await fiUSD.getAddress()))
        // console.log('fiETH vault: ' + await cofiMoney.getVault(await fiETH.getAddress()))
        // console.log('fiBTC vault: ' + await cofiMoney.getVault(await fiBTC.getAddress()))

        await fiUSD.approve(
            await cofiMoney.getAddress(),
            await fiUSD.balanceOf(await owner.getAddress())
        )
        // await fiBTC.approve(
        //     await cofiMoney.getAddress(),
        //     await fiBTC.balanceOf(await owner.getAddress())
        // )
        console.log("Approved diamond spend")

        // Redeem
        await cofiMoney.fiToUnderlying(
            await fiUSD.balanceOf(await owner.getAddress()),
            "1100000000", // [USDC]
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress()
        )
        // await cofiMoney.fiToUnderlying(
        //     await fiBTC.balanceOf(await owner.getAddress()),
        //     "10500000", // [wBTC]
        //     await fiBTC.getAddress(),
        //     await owner.getAddress(),
        //     await owner.getAddress()
        // )

        console.log('t3 fiUSD total supply: ' + await fiUSD.totalSupply())
        // console.log('t3 fiBTC total supply: ' + await fiBTC.totalSupply())
        console.log('t3 Owner fiUSD bal: ' + await fiUSD.balanceOf(await owner.getAddress()))
        // console.log('t3 Owner fiBTC bal: ' + await fiBTC.balanceOf(await owner.getAddress()))

        // Do user deposit
        await usdc.approve(await cofiMoney.getAddress(), "1100000000")
        // await wbtc.approve(await cofiMoney.getAddress(), "10500000")
        await cofiMoney.underlyingToFi(
            "1100000000", // 1,100 USDC
            "1096975000000000000000", // 0.25% slippage [fiUSD]
            await fiUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        // await cofiMoney.underlyingToFi(
        //     "10500000", // 0.105 wBTC
        //     "104711250000000000", // 0.25% slippage [fiBTC]
        //     await fiBTC.getAddress(),
        //     await owner.getAddress(),
        //     await owner.getAddress(),
        //     NULL_Addr
        // )

        console.log('t4 fiUSD total supply: ' + await fiUSD.totalSupply())
        // console.log('t4 fiBTC total supply: ' + await fiBTC.totalSupply())
        console.log('t4 Owner fiUSD bal: ' + await fiUSD.balanceOf(await owner.getAddress()))
        // console.log('t4 Owner fiBTC bal: ' + await fiBTC.balanceOf(await owner.getAddress()))
    })
})