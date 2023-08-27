/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const DAI_ABI = require("./abi/DAI_Optimism.json")
const WETH_ABI = require("./abi/WETH.json")
const OP_ABI = require("./abi/OP.json")
const YVUSDC_ABI = require("./abi/YVUSDC.json")
const YVETH_ABI = require("./abi/YVETH.json")

const WBTC_ABI = require("./abi/WBTC.json")
const SOTKN_ABI = require("./abi/SOTOKEN.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const DAI_Addr = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"
const WETH_Addr = "0x4200000000000000000000000000000000000006"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const YVUSDC_Addr = "0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2"
const YVETH_Addr = "0x5B977577Eb8a480f63e11FC615D6753adB8652Ae"
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const StakingRewards_YVUSDC_Addr = "0xB2c04C55979B6CA7EB10e666933DE5ED84E6876b"
const StakingRewards_YVETH_Addr = "0xE35Fec3895Dcecc7d2a91e8ae4fF3c0d43ebfFE0"

const WBTC_Addr = "0x68f180fcCe6836688e9084f035309E29Bf0A2095"
const SOUSDC_Addr = "0xEC8FEa79026FfEd168cCf5C627c7f486D77b765F"
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
const whaleDai = "0x128D525C25061f664bBA8917240af8FE949ca1cA"
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

        const signer = await ethers.provider.getSigner(0)
        const backupSigner = await ethers.provider.getSigner(1)
        const wueSigner = await ethers.getImpersonatedSigner(whaleUsdcEth)
        const wdiSigner = await ethers.getImpersonatedSigner(whaleDai)
        const wbtSigner = await ethers.getImpersonatedSigner(whaleBtc)
        const wopSigner = await ethers.getImpersonatedSigner(whaleOp)

        console.log(await helpers.time.latestBlock())

        /* Deploy wrappers */

        // const wsoUSDC = await ethers.getContractFactory("YearnV2ERC4626Reinvest")
        // const wsoUSDC = await wsoUSDC.deploy(
        //     YVUSDC_Addr,
        //     YVOP_Addr,
        //     StakingRewards_YVUSDC_Addr,
        //     "0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3",
        //     USDC_Addr, // want
        //     getRewardMin,
        //     amountInMin,
        //     slippage,
        //     wait,
        //     poolFee,
        //     {gasLimit: "30000000"}
        // )
        // await wsoUSDC.waitForDeployment()
        // console.log("wsoUSDC deployed: ", await wsoUSDC.getAddress())

        const WSOUSDC = await ethers.getContractFactory("CompoundV2ERC4626Reinvest")
        const wsoUSDC = await WSOUSDC.deploy(
            USDC_Addr,
            OP_Addr,
            SOUSDC_Addr,
            COMPTROLLER_Addr,
            "0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3", // USDC price feed
            "1000000000000000000", // amountInMin = 1 OP
            "200", // slippage = 2%
            "12" // wait = 12 seconds
        )
        await wsoUSDC.waitForDeployment()
        console.log("wsoUSDC deployed: ", await wsoUSDC.getAddress())
        // Although OP-USDC pool exists, OP-wETH-USDC provides better exchange rate.
        await wsoUSDC.setRoute("500", WETH_Addr, "500")
    
        const WYVETH = await ethers.getContractFactory("YearnV2ERC4626Reinvest")
        const wyvETH = await WYVETH.deploy(
            YVETH_Addr,
            YVOP_Addr,
            StakingRewards_YVETH_Addr,
            "0x13e3Ee699D1909E989722E753853AE30b17e08c5", // ETH price feed
            WETH_Addr,
            getRewardMin,
            amountInMin,
            slippage,
            wait,
            poolFee,
            {gasLimit: "30000000"}
        )
        await wyvETH.waitForDeployment()
        console.log("wyvETH deployed: ", await wyvETH.getAddress())

        const WSOBTC = await ethers.getContractFactory("CompoundV2ERC4626Reinvest")
        const wsoBTC = await WSOBTC.deploy(
            WBTC_Addr,
            OP_Addr,
            SOWBTC_Addr,
            COMPTROLLER_Addr,
            "0xd702dd976fb76fffc2d3963d037dfdae5b04e593", // BTC price feed
            "1000000000000000000", // amountInMin = 1 OP
            "200", // slippage = 2%
            "12" // wait = 12 seconds
        )
        await wsoBTC.waitForDeployment()
        console.log("wsoBTC deployed: ", await wsoBTC.getAddress())
        // Changed from 0.3% for each.
        await wsoBTC.setRoute("500", WETH_Addr, "500")

        /* Deploy COFI tokens */

        const COUSD = await ethers.getContractFactory("COFIRebasingToken")
        const coUSD = await COUSD.deploy(
            "COFI Dollar",
            "coUSD"
        )
        await coUSD.waitForDeployment()
        console.log("coUSD deployed: " + await coUSD.getAddress())

        const COETH = await ethers.getContractFactory("COFIRebasingToken")
        const coETH = await COETH.deploy(
            "COFI Ethereum",
            "coETH"
        )
        await coETH.waitForDeployment()
        console.log("coETH deployed: " + await coETH.getAddress())

        const COBTC = await ethers.getContractFactory("COFIRebasingToken")
        const coBTC = await COBTC.deploy(
            "COFI Bitcoin",
            "coBTC"
        )
        await coBTC.waitForDeployment()
        console.log("coBTC deployed: " + await coBTC.getAddress())

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

        // Set Diamond address in COFI token contracts.
        await coUSD.setApp(await diamond.getAddress())
        console.log("Diamond address set in coUSD")
        await coETH.setApp(await diamond.getAddress())
        console.log("Diamond address set in coETH")
        await coBTC.setApp(await diamond.getAddress())
        console.log("Diamond address set in coBTC")

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
        'AccountManagerFacet',
        'PointFacet',
        'SupplyFacet',
        'SupplyManagerFacet',
        'SwapManagerFacet',
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
            coETH:  await coETH.getAddress(),
            coBTC:  await coBTC.getAddress(),
            vUSDC:  await wsoUSDC.getAddress(),
            vETH:   await wyvETH.getAddress(),
            vBTC:   await wsoBTC.getAddress(),
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
        await wsoUSDC.setAuthorized(await diamond.getAddress(), "1")
        // Need to set "rewardShareReceiver" for Yearn wrappers.
        // await wsoUSDC.setRewardShareReceiver(await diamond.getAddress())
        await wyvETH.setAuthorized(await diamond.getAddress(), "1")
        await wyvETH.setRewardShareReceiver(await diamond.getAddress())
        await wsoBTC.setAuthorized(await diamond.getAddress(), "1")
        console.log("Authorized Diamond interaction with wrappers")

        /* Whitelist user */
        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)
        await cofiMoney.setWhitelist((await owner.getAddress()), "1")
        console.log("Whitelisted user")

        /* Transfer user assets */
        const wue_usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(wueSigner)
        await wue_usdc.transfer((await owner.getAddress()), "10000000000") // 10,000 USDC
        console.log("Transferred USDC to user")
        const wue_dai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(wdiSigner)
        await wue_dai.transfer((await owner.getAddress()), ethers.parseEther('10000')) // 10,000 DAI
        console.log("Transferred DAI to user")
        const wue_eth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(wueSigner)
        await wue_eth.transfer((await owner.getAddress()), ethers.parseEther('10')) // 10 wETH
        console.log("Transferred wETH to user")
        const wbt_btc = (await ethers.getContractAt(WBTC_ABI, WBTC_Addr)).connect(wbtSigner)
        await wbt_btc.transfer((await owner.getAddress()), "50000000") // 0.5 wBTC
        console.log("Transferred wBTC to user")

        /* Migration test - transfer 10x buffer */
        await wue_usdc.transfer((await diamond.getAddress()), "100000000") // 100 USDC
        await wue_eth.transfer((await diamond.getAddress()), ethers.parseEther('0.1')) // 0.1 wETH
        await wbt_btc.transfer((await diamond.getAddress()), "1000000") // 0.01 wBTC

        // Approvals
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        await usdc.approve(await diamond.getAddress(), await usdc.balanceOf(await owner.getAddress())) // 10,000 USDC
        console.log("Approved USDC")

        const dai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(signer)
        await dai.approve(await diamond.getAddress(), await dai.balanceOf(await owner.getAddress())) // 10,000 DAI
        console.log("Approved DAI")

        const weth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(signer)
        await weth.approve(await diamond.getAddress(), await weth.balanceOf(await owner.getAddress())) // 10 wETH
        console.log("Approved wETH")

        const wbtc = (await ethers.getContractAt(WBTC_ABI, WBTC_Addr)).connect(signer)
        await wbtc.approve(await diamond.getAddress(), await wbtc.balanceOf(await owner.getAddress())) // 0.5 wBTC
        console.log("Approved wBTC")

        /* Set up executable yield distribution */
        const wop_op = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(wopSigner)
        await wop_op.transfer(await wsoUSDC.getAddress(), ethers.parseEther('10')) // 10 OP
        await wop_op.transfer(await wyvETH.getAddress(), ethers.parseEther('10')) // 10 OP
        await wop_op.transfer(await wsoBTC.getAddress(), ethers.parseEther('10')) // 10 OP
        console.log("Transferred OP to wrappers")

        /* Migration test - do a rebase beforehand to better simulate in live env */
        // await cofiMoney.rebase(await coUSD.getAddress())
        // await cofiMoney.rebase(await coETH.getAddress())
        // await cofiMoney.rebase(await coBTC.getAddress())

        // console.log('t1 coUSD yield earned: ' + await coUSD.getYieldEarned(await owner.getAddress()))
        // console.log('t1 coETH yield earned: ' + await coETH.getYieldEarned(await owner.getAddress()))
        // console.log('t1 coBTC yield earned: ' + await coBTC.getYieldEarned(await owner.getAddress()))

        return { owner, feeCollector, wsoUSDC, wyvETH, wsoBTC, coUSD, coETH, coBTC, usdc, dai, weth, wbtc, cofiMoney }
    }

    // it("Should enable User to deposit ETH and receive coUSD", async function() {

    //     const { owner, feeCollector, coUSD, usdc, wsoUSDC, cofiMoney } = await loadFixture(deploy)

    //     await cofiMoney.ETHToCofi(
    //         await coUSD.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr,
    //         {value: ethers.parseEther('1')}
    //     )

    //     console.log("t0 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t0 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
    //     console.log("t0 Diamond wsoUSDC bal: ", await wsoUSDC.balanceOf(await cofiMoney.getAddress()))
    // })

    // it("Should enable User to deposit ETH and receive coETH", async function() {

    //     const { owner, feeCollector, coETH, wyvETH, cofiMoney } = await loadFixture(deploy)

    //     await cofiMoney.ETHToCofi(
    //         await coETH.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr,
    //         {value: ethers.parseEther('1')}
    //     )

    //     console.log("t0 User coETH bal: ", await coETH.balanceOf(await owner.getAddress()))
    //     console.log("t0 Fee Collector coETH bal: ", await coETH.balanceOf(await feeCollector.getAddress()))
    //     console.log("t0 Diamond wyvETH bal: ", await wyvETH.balanceOf(await cofiMoney.getAddress()))
    // })

    // it("Should enable User to deposit ETH and receive coBTC", async function() {

    //     const { owner, feeCollector, coBTC, wsoBTC, cofiMoney } = await loadFixture(deploy)

    //     await cofiMoney.ETHToCofi(
    //         await coBTC.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr,
    //         {value: ethers.parseEther('1')}
    //     )

    //     console.log("t0 User coBTC bal: ", await coBTC.balanceOf(await owner.getAddress()))
    //     console.log("t0 Fee Collector coBTC bal: ", await coBTC.balanceOf(await feeCollector.getAddress()))
    //     console.log("t0 Diamond wsoBTC bal: ", await wsoBTC.balanceOf(await cofiMoney.getAddress()))
    // })

    it("Should enable User to deposit USDC and receive coUSD", async function() {

        const { owner, feeCollector, coUSD, wsoUSDC, usdc, cofiMoney } = await loadFixture(deploy)

        await cofiMoney.tokensToCofi(
            await usdc.balanceOf(await owner.getAddress()),
            USDC_Addr,
            await coUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )

        console.log("t0 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Diamond wsoUSDC bal: ", await wsoUSDC.balanceOf(await cofiMoney.getAddress()))
    })

    it("Should enable User to deposit wETH and receive coETH", async function() {

        const { owner, feeCollector, coETH, wyvETH, weth, cofiMoney } = await loadFixture(deploy)

        await cofiMoney.tokensToCofi(
            await weth.balanceOf(await owner.getAddress()),
            WETH_Addr,
            await coETH.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )

        console.log("t0 User coETH bal: ", await coETH.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector coETH bal: ", await coETH.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Diamond wyvETH bal: ", await wyvETH.balanceOf(await cofiMoney.getAddress()))
    })

    it("Should enable User to deposit wBTC and receive coBTC", async function() {

        const { owner, feeCollector, coBTC, wsoBTC, wbtc, cofiMoney } = await loadFixture(deploy)

        await cofiMoney.tokensToCofi(
            await wbtc.balanceOf(await owner.getAddress()),
            WBTC_Addr,
            await coBTC.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )

        console.log("t0 User coBTC bal: ", await coBTC.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector coBTC bal: ", await coBTC.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Diamond wsoBTC bal: ", await wsoBTC.balanceOf(await cofiMoney.getAddress()))
    })

    it("Should enable User to deposit DAI and receive coUSD", async function() {

        const { owner, feeCollector, coUSD, wsoUSDC, usdc, dai, cofiMoney } = await loadFixture(deploy)

        const fromTo = await cofiMoney.getConversion(
            await dai.balanceOf(await owner.getAddress()),
            '0',
            DAI_Addr,
            USDC_Addr
        )
        console.log("Dai bal [USDC]: ", fromTo)

        const coUSDOut = await cofiMoney.getEstimatedCofiOut(
            await dai.balanceOf(await owner.getAddress()),
            DAI_Addr,
            await coUSD.getAddress()
        )
        console.log("Estimated coUSD out: ", coUSDOut)

        await cofiMoney.tokensToCofi(
            await dai.balanceOf(await owner.getAddress()),
            DAI_Addr,
            await coUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )

        console.log("t0 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t0 Diamond wsoUSDC bal: ", await wsoUSDC.balanceOf(await cofiMoney.getAddress()))
    })
})