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
const WBTC_ABI = require("./abi/WBTC.json")
const OP_ABI = require("./abi/OP.json")
const SOTKN_ABI = require("./abi/SOTKN.json")
const YVTKN_ABI = require("./abi/YVTKN.json")

const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const DAI_Addr = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"
const WETH_Addr = "0x4200000000000000000000000000000000000006"
const WBTC_Addr = "0x68f180fcCe6836688e9084f035309E29Bf0A2095"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const YVUSDC_Addr = "0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2"
const YVDAI_Addr = "0x65343F414FFD6c97b0f6add33d16F6845Ac22BAc"
const YVETH_Addr = "0x5B977577Eb8a480f63e11FC615D6753adB8652Ae"
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const StakingRewards_YVUSDC_Addr = "0xB2c04C55979B6CA7EB10e666933DE5ED84E6876b"
const StakingRewards_YVDAI_Addr = "0xf8126EF025651E1B313a6893Fcf4034F4F4bD2aA"
const StakingRewards_YVETH_Addr = "0xE35Fec3895Dcecc7d2a91e8ae4fF3c0d43ebfFE0"
const SOUSDC_Addr = "0xEC8FEa79026FfEd168cCf5C627c7f486D77b765F"
const SOWETH_Addr = "0xf7B5965f5C117Eb1B5450187c9DcFccc3C317e8E"
const SOWBTC_Addr = "0x33865E09A572d4F1CC4d75Afc9ABcc5D3d4d867D"

const NULL_Addr = "0x0000000000000000000000000000000000000000"

/* Yearn Swap Params */

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "1500" // 15%
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

        /* 1. Deploy wrappers */

        const WYVTKNSTK = await ethers.getContractFactory("YearnV2StakingRewards")
        // const wyvUSDC = await WYVTKN.deploy(
        //     YVUSDC_Addr,
        //     YVOP_Addr,
        //     StakingRewards_YVUSDC_Addr,
        //     "0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3", // USDC price feed
        //     USDC_Addr, // want
        //     getRewardMin,
        //     amountInMin,
        //     slippage,
        //     wait,
        //     poolFee,
        //     {gasLimit: "30000000"}
        // )
        // await wyvUSDC.waitForDeployment()
        // console.log("wyvUSDC deployed: ", await wyvUSDC.getAddress())
        // // Swap path already set via constructor for Yearn wrappers.

        const WSOTKN = await ethers.getContractFactory("CompoundV2Reinvest")
        const wsoUSDC = await WSOTKN.deploy(
            USDC_Addr,
            OP_Addr,
            SOUSDC_Addr,
            "0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3", // USDC price feed
            "1000000000000000000", // amountInMin = 1 OP
            slippage,
            wait
        )
        await wsoUSDC.waitForDeployment()
        console.log("wsoUSDC deployed: ", await wsoUSDC.getAddress())
        // Although OP-USDC pool exists, OP-wETH-USDC provides better exchange rate.
        await wsoUSDC.setRoute("500", WETH_Addr, "500")

        const wyvDAI = await WYVTKNSTK.deploy(
            YVDAI_Addr,
            YVOP_Addr,
            StakingRewards_YVDAI_Addr,
            "0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6", // DAI price feed
            getRewardMin,
            amountInMin,
            slippage,
            wait,
            poolFee,
            "1",
            {gasLimit: "30000000"}
        )
        await wyvDAI.waitForDeployment()
        console.log("wyvDAI deployed: ", await wyvDAI.getAddress())
    
        const wyvETH = await WYVTKNSTK.deploy(
            YVETH_Addr,
            YVOP_Addr,
            StakingRewards_YVETH_Addr,
            "0x13e3Ee699D1909E989722E753853AE30b17e08c5", // ETH price feed
            getRewardMin,
            amountInMin,
            slippage,
            wait,
            poolFee,
            "1",
            {gasLimit: "30000000"}
        )
        await wyvETH.waitForDeployment()
        console.log("wyvETH deployed: ", await wyvETH.getAddress())

        // const wsoETH = await WSOTKN.deploy(
        //     WETH_Addr,
        //     OP_Addr,
        //     SOWETH_Addr,
        //     "0x13e3Ee699D1909E989722E753853AE30b17e08c5", // ETH price feed
        //     "1000000000000000000", // amountInMin = 1 OP
        //     "200", // slippage = 2%
        //     "12" // wait = 12 seconds
        // )
        // await wsoETH.waitForDeployment()
        // console.log("wsoUSDC deployed: ", await wsoETH.getAddress())
        // // Although OP-USDC pool exists, OP-wETH-USDC provides better exchange rate.
        // await wsoETH.setPath("500", WETH_Addr, "500")

        const wsoBTC = await WSOTKN.deploy(
            WBTC_Addr,
            OP_Addr,
            SOWBTC_Addr,
            "0xd702dd976fb76fffc2d3963d037dfdae5b04e593", // BTC price feed
            "1000000000000000000", // amountInMin = 1 OP
            "200", // slippage = 2%
            "12" // wait = 12 seconds
        )
        await wsoBTC.waitForDeployment()
        console.log("wsoBTC deployed: ", await wsoBTC.getAddress())
        // Changed from 0.3% for each.
        await wsoBTC.setRoute("500", WETH_Addr, "500")

        const WYVTKN = await ethers.getContractFactory("YearnV2")
        const wyvOP = await WYVTKN.deploy(
            YVOP_Addr
            // {gasLimit: "30000000"}
        )
        await wyvOP.waitForDeployment()
        console.log("wyvOP deployed: ", await wyvOP.getAddress())

        /* Deploy COFI tokens */

        const COTKN = await ethers.getContractFactory("COFIRebasingToken")
        const coUSD = await COTKN.deploy(
            "COFI Dollar (Optimism)",
            "coUSD"
        )
        await coUSD.waitForDeployment()
        console.log("coUSD deployed: " + await coUSD.getAddress())

        const coETH = await COTKN.deploy(
            "COFI Ethereum (Optimism)",
            "coETH"
        )
        await coETH.waitForDeployment()
        console.log("coETH deployed: " + await coETH.getAddress())

        const coBTC = await COTKN.deploy(
            "COFI Bitcoin (Optimism)",
            "coBTC"
        )
        await coBTC.waitForDeployment()
        console.log("coBTC deployed: " + await coBTC.getAddress())

        const coOP = await COTKN.deploy(
            "COFI Optimsim (Optimism)",
            "coOP"
        )
        await coOP.waitForDeployment()
        console.log("coBTC deployed: " + await coOP.getAddress())

        /* 3. Diamond deployment */

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
        'PointsManagerFacet',
        'SupplyFacet',
        'SupplyManagerFacet',
        'SwapManagerFacet',
        'VaultManagerFacet'
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
            coOP:   await coOP.getAddress(),
            vUSD:  await wyvDAI.getAddress(), // wsoUSDC.getAddress(),
            vETH:   await wyvETH.getAddress(),
            vBTC:   await wsoBTC.getAddress(),
            vOP:    await wyvOP.getAddress(),
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

        /* 4. Set up */

        // Set Diamond address in COFI token contracts.
        await coUSD.setApp(await diamond.getAddress())
        console.log("Diamond address set in coUSD")
        await coETH.setApp(await diamond.getAddress())
        console.log("Diamond address set in coETH")
        await coBTC.setApp(await diamond.getAddress())
        console.log("Diamond address set in coBTC")
        await coOP.setApp(await diamond.getAddress())
        console.log("Diamond address set in coOP")

        // Authorize Diamond to interact with wrappers
        await wsoUSDC.setAuthorized(await diamond.getAddress(), "1")
        // Need to set "rewardShareReceiver" for Yearn wrappers.
        // await wsoUSDC.setRewardShareReceiver(await diamond.getAddress())
        await wyvETH.setAuthorized(await diamond.getAddress(), "1")
        await wyvETH.setRewardShareReceiver(await diamond.getAddress())
        await wyvDAI.setAuthorized(await diamond.getAddress(), "1")
        await wyvDAI.setRewardShareReceiver(await diamond.getAddress())
        await wsoBTC.setAuthorized(await diamond.getAddress(), "1")
        await wyvOP.setAuthorized(await diamond.getAddress(), "1")
        await wyvOP.setFlushReceiver(await diamond.getAddress())
        console.log("Authorized Diamond interaction with wrappers")

        /* Whitelist user */
        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)
        await cofiMoney.setWhitelist((await owner.getAddress()), "1")
        console.log("Whitelisted user")

        /* Transfer user assets */
        const wue_usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(wueSigner)
        await wue_usdc.transfer(await owner.getAddress(), "10000000000") // 10,000 USDC
        console.log("Transferred USDC to user")
        const wue_dai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(wdiSigner)
        await wue_dai.transfer(await owner.getAddress(), ethers.parseEther('10000')) // 10,000 DAI
        console.log("Transferred DAI to user")
        const wue_eth = (await ethers.getContractAt(WETH_ABI, WETH_Addr)).connect(wueSigner)
        await wue_eth.transfer(await owner.getAddress(), ethers.parseEther('10')) // 10 wETH
        console.log("Transferred wETH to user")
        const wbt_btc = (await ethers.getContractAt(WBTC_ABI, WBTC_Addr)).connect(wbtSigner)
        await wbt_btc.transfer(await owner.getAddress(), "50000000") // 0.5 wBTC
        console.log("Transferred wBTC to user")
        const wop_op = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(wopSigner)
        await wop_op.transfer(await owner.getAddress(), ethers.parseEther('1000')) // 1,000 OP
        console.log("Transferred OP to user")

        /* Set up executable yield distribution */
        await wop_op.transfer(await wsoUSDC.getAddress(), ethers.parseEther('100')) // 100 OP
        await wop_op.transfer(await wyvDAI.getAddress(), ethers.parseEther('100')) // 100 OP
        await wop_op.transfer(await wyvETH.getAddress(), ethers.parseEther('100')) // 100 OP
        await wop_op.transfer(await wsoBTC.getAddress(), ethers.parseEther('100')) // 100 OP
        // As wyvOP is not reinvesting, transfer OP to vault wrapped.
        await wop_op.transfer(YVOP_Addr, ethers.parseEther('100')) // 100 OP
        console.log("Transferred OP to wrappers")

        /* Migration test - transfer 10x buffer */
        await wue_usdc.transfer((await diamond.getAddress()), "100000000") // 100 USDC
        await wue_dai.transfer((await diamond.getAddress()), ethers.parseEther('100')) // 100 DAI
        await wue_eth.transfer((await diamond.getAddress()), ethers.parseEther('0.1')) // 0.1 wETH
        await wbt_btc.transfer((await diamond.getAddress()), "1000000") // 0.01 wBTC
        await wop_op.transfer((await diamond.getAddress()), ethers.parseEther('100')) // 100 OP

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

        const op = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(signer)
        await op.approve(await diamond.getAddress(), await op.balanceOf(await owner.getAddress())) // 0.5 wBTC
        console.log("Approved OP")
        // Register harvest.
        await op.transfer(await wyvOP.getAddress(), ethers.parseEther('100'))

        /* Migration test - do a rebase beforehand to better simulate in live env */
        // await cofiMoney.rebase(await coUSD.getAddress())
        // await cofiMoney.rebase(await coETH.getAddress())
        // await cofiMoney.rebase(await coBTC.getAddress())

        // console.log('t1 coUSD yield earned: ' + await coUSD.getYieldEarned(await owner.getAddress()))
        // console.log('t1 coETH yield earned: ' + await coETH.getYieldEarned(await owner.getAddress()))
        // console.log('t1 coBTC yield earned: ' + await coBTC.getYieldEarned(await owner.getAddress()))

        return { owner, feeCollector, wsoUSDC, wyvDAI, wyvETH, wsoBTC, wyvOP, coUSD, coETH, coBTC, coOP, usdc, 
            dai, weth, wbtc, op, wop_op, cofiMoney }
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

    // it("Should enable User to deposit ETH and receive coBTC", async function() { // X

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

    it("Should get correct estimation values", async function() {

        const { owner, feeCollector, wyvDAI, coUSD, coETH, coBTC, usdc, cofiMoney } = await loadFixture(deploy)

        let est_coTKN = await cofiMoney.getEstimatedCofiOut(
            ethers.parseEther('1'),
            WETH_Addr,
            await coUSD.getAddress()
        )
        console.log("t0 Estimated coUSD received: ", est_coTKN)

        est_coTKN = await cofiMoney.getEstimatedCofiOut(
            '100000000',
            USDC_Addr,
            await coUSD.getAddress()
        )
        console.log("t0 Estimated coUSD received: ", est_coTKN)

        est_coTKN = await cofiMoney.getEstimatedCofiOut(
            ethers.parseEther('1'),
            WETH_Addr,
            await coETH.getAddress()
        )
        console.log("t0 Estimated coETH received: ", est_coTKN)

        est_coTKN = await cofiMoney.getEstimatedCofiOut(
            ethers.parseEther('1'),
            WETH_Addr,
            await coBTC.getAddress()
        )
        console.log("t0 Estimated coBTC received: ", est_coTKN)

        est_coTKN = await cofiMoney.getEstimatedTokensOut(
            ethers.parseEther('1630'),
            await coUSD.getAddress(),
            WETH_Addr
        )
        console.log("t0 Estimated wETH received: ", est_coTKN)

        est_coTKN = await cofiMoney.getEstimatedTokensOut(
            ethers.parseEther('1630'),
            await coUSD.getAddress(),
            USDC_Addr
        )
        console.log("t0 Estimated USDC received: ", est_coTKN)

        est_coTKN = await cofiMoney.getEstimatedTokensOut(
            ethers.parseEther('1'),
            await coETH.getAddress(),
            USDC_Addr
        )
        console.log("t0 Estimated USDC received: ", est_coTKN)

        est_coTKN = await cofiMoney.getEstimatedTokensOut(
            ethers.parseEther('0.06'),
            await coBTC.getAddress(),
            WBTC_Addr
        )
        console.log("t0 Estimated wBTC received: ", est_coTKN)
    }) //0.06000000_0000000000 10 decimals off

    // it("Should do deposit, rebase, and withdraw sequence (ETH => coTKN => ETH)", async function() {
    //     // ETH => 1. coUSD; 2. coETH; 3. coBTC; 4. coOP; 5. coUSD (DAI) => ETH
    //         // getEstimatedCofiOut: 1, 2, 3, 4, 5
    //         // ETHToCofi: 1, 2, 3, 4, 5
    //         // rebase : 1, 2, 3, 4, 5
    //         // getEstimatedTokensOut (ETH): 1, 2, 3, 4, 5
    //         // cofiToETH: 1, 2, 3, 4, 5

    //     const { owner, feeCollector, wyvDAI, coUSD, usdc, cofiMoney } = await loadFixture(deploy)

    //     // Get estimated coUSD out.
    //     const est_coTKN = await cofiMoney.getEstimatedCofiOut(
    //         ethers.parseEther('1'),
    //         WETH_Addr,
    //         await coUSD.getAddress()
    //     )
    //     console.log("t0 Estimated coUSD received: ", est_coTKN)
    //     console.log("t0 User ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))

        // await cofiMoney.enterCofi(
        //     ethers.parseEther('1'), //_tokensIn is irrelevant
        //     WETH_Addr, // _token is irrelevant
        //     await coUSD.getAddress(),
        //     await owner.getAddress(), // depositFrom is irrelevant.
        //     await owner.getAddress(),
        //     NULL_Addr,
        //     {value: ethers.parseEther('1')} // Pass amount here as 'value'
        // )

    //     console.log("t1 User coUSD pre-rebase bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t1 ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))
    //     console.log("t1 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
    //     console.log("t1 Diamond wyvDAI bal: ", await wyvDAI.balanceOf(await cofiMoney.getAddress()))

    //     await cofiMoney.rebase(await coUSD.getAddress())

    //     console.log("t2 User coUSD post-rebase bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t2 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))

    //     const estETH = await cofiMoney.getEstimatedTokensOut(
    //         await coUSD.balanceOf(await owner.getAddress()),
    //         await coUSD.getAddress(),
    //         WETH_Addr
    //     )
    //     console.log("t3 Estimated ETH received: ", estETH)
    //     console.log("t3 User ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))

    //     await coUSD.approve(await cofiMoney.getAddress(), await coUSD.balanceOf(await owner.getAddress()))

    //     await cofiMoney.exitCofi(
    //         await coUSD.balanceOf(await owner.getAddress()),
    //         USDC_Addr, // Use to request native ETH.
    //         await coUSD.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress()
    //     )

    //     console.log("t4 USDC bal: ", await usdc.balanceOf(await owner.getAddress()))
    //     console.log("t4 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t4 ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))
    //     console.log("t4 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
    //     console.log("t4 Diamond wyvDAI bal: ", await wyvDAI.balanceOf(await cofiMoney.getAddress()))
    // })

    // it("Should enable User to deposit USDC and receive coUSD", async function() {

    //     const { owner, feeCollector, coUSD, wsoUSDC, usdc, cofiMoney } = await loadFixture(deploy)

    //     await cofiMoney.enterCofi(
    //         await usdc.balanceOf(await owner.getAddress()),
    //         USDC_Addr,
    //         await coUSD.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr
    //     )

    //     console.log("t0 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t0 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
    //     console.log("t0 Diamond wsoUSDC bal: ", await wsoUSDC.balanceOf(await cofiMoney.getAddress()))
    // })

    // it("Should enable User to deposit OP and receive coETH", async function() {

    //     const { owner, feeCollector, coETH, wyvETH, op, cofiMoney } = await loadFixture(deploy)

    //     await cofiMoney.setV3Route(
    //         WETH_Addr,
    //         "500",
    //         NULL_Addr,
    //         "0",
    //         OP_Addr
    //     )
    //     console.log("Route set")
    //     await cofiMoney.setSwapProtocol(
    //         WETH_Addr,
    //         OP_Addr,
    //         2
    //     )
    //     console.log("Protocol set")

    //     await cofiMoney.enterCofi(
    //         await op.balanceOf(await owner.getAddress()),
    //         OP_Addr,
    //         await coETH.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr
    //     )

    //     console.log("t0 User coETH bal: ", await coETH.balanceOf(await owner.getAddress()))
    //     console.log("t0 Fee Collector coETH bal: ", await coETH.balanceOf(await feeCollector.getAddress()))
    //     console.log("t0 Diamond wyvETH bal: ", await wyvETH.balanceOf(await cofiMoney.getAddress()))
    // })

    // it("Should migrate coUSD backing from wyvDAI to wsoUSDC", async function() {

    //     const { owner, feeCollector, coUSD, wyvDAI, wsoUSDC, dai, cofiMoney } = await loadFixture(deploy)

    //     // Initial deposit
    //     await cofiMoney.enterCofi(
    //         ethers.parseEther('1000'),
    //         DAI_Addr,
    //         await coUSD.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr,
    //         // {value: ethers.parseEther('1')}
    //     )

    //     console.log("t1 User coUSD pre-rebase bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t1 ETH bal: ", await ethers.provider.getBalance(await owner.getAddress()))
    //     console.log("t1 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
    //     console.log("t1 Diamond wyvDAI bal: ", await wyvDAI.balanceOf(await cofiMoney.getAddress()))

    //     await cofiMoney.rebase(await coUSD.getAddress())

    //     console.log("t2 User coUSD post-rebase bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t2 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))

    //     await cofiMoney.setMigrationEnabled(
    //         await wyvDAI.getAddress(),
    //         await wsoUSDC.getAddress(),
    //         1
    //     )

    //     await cofiMoney.migrate(
    //         await coUSD.getAddress(),
    //         await wsoUSDC.getAddress()
    //     )

    //     console.log("t3 User coUSD post-migration bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t3 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))

    //     // 2nd deposit
    //     await cofiMoney.enterCofi(
    //         ethers.parseEther('1000'),
    //         DAI_Addr,
    //         await coUSD.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr,
    //         // {value: ethers.parseEther('1')}
    //     )

    //     console.log("t4 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t4 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
    // })

    // it("Should get correct storage variables from SwapManagerFacet", async function() {

    //     const { coUSD, coETH, coBTC, cofiMoney } = await loadFixture(deploy)

    //     console.log("Get WETH<>WBTC SP: ", await cofiMoney.getSwapProtocol(WETH_Addr, WBTC_Addr))

    //     console.log("Get WEH supported swaps: ", await cofiMoney.getSupportedSwaps(WETH_Addr))
    //     console.log("Get coETH supported swaps: ", await cofiMoney.getSupportedSwaps(await coETH.getAddress()))
    // })

    // it("Should enable User to deposit wBTC and receive coBTC", async function() {

    //     const { owner, feeCollector, coBTC, wsoBTC, wbtc, cofiMoney } = await loadFixture(deploy)

    //     await cofiMoney.tokensToCofi(
    //         await wbtc.balanceOf(await owner.getAddress()),
    //         WBTC_Addr,
    //         await coBTC.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr
    //     )

    //     console.log("t0 User coBTC bal: ", await coBTC.balanceOf(await owner.getAddress()))
    //     console.log("t0 Fee Collector coBTC bal: ", await coBTC.balanceOf(await feeCollector.getAddress()))
    //     console.log("t0 Diamond wsoBTC bal: ", await wsoBTC.balanceOf(await cofiMoney.getAddress()))
    // })

    // it("Should enable User to deposit OP and receive coOP", async function() {

    //     const { owner, feeCollector, coOP, wyvOP, op, cofiMoney } = await loadFixture(deploy)

    //     await cofiMoney.tokensToCofi(
    //         await op.balanceOf(await owner.getAddress()),
    //         OP_Addr,
    //         await coOP.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr
    //     )

    //     console.log("t0 User coOP bal: ", await coOP.balanceOf(await owner.getAddress()))
    //     console.log("t0 Fee Collector coOP bal: ", await coOP.balanceOf(await feeCollector.getAddress()))
    //     console.log("t0 Diamond wyvOP bal: ", await wyvOP.balanceOf(await cofiMoney.getAddress()))
    // })

    // it("Should enable User to deposit DAI and receive coUSD", async function() {

    //     const { owner, feeCollector, coUSD, wsoUSDC, usdc, dai, cofiMoney } = await loadFixture(deploy)

    //     const fromTo = await cofiMoney.getConversion(
    //         await dai.balanceOf(await owner.getAddress()),
    //         '0',
    //         DAI_Addr,
    //         USDC_Addr
    //     )
    //     console.log("Dai bal [USDC]: ", fromTo)

    //     const coUSDOut = await cofiMoney.getEstimatedCofiOut(
    //         await dai.balanceOf(await owner.getAddress()),
    //         DAI_Addr,
    //         await coUSD.getAddress()
    //     )
    //     console.log("Estimated coUSD out: ", coUSDOut)

    //     await cofiMoney.tokensToCofi(
    //         await dai.balanceOf(await owner.getAddress()),
    //         DAI_Addr,
    //         await coUSD.getAddress(),
    //         await owner.getAddress(),
    //         await owner.getAddress(),
    //         NULL_Addr
    //     )

    //     console.log("t0 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
    //     console.log("t0 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
    //     console.log("t0 Diamond wsoUSDC bal: ", await wsoUSDC.balanceOf(await cofiMoney.getAddress()))
    // })
})