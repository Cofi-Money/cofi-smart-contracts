/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const DAI_ABI = require("./abi/DAI_Optimism.json")
const OP_ABI = require("./abi/OP.json")

const USDCWhale_Addr = "0x16224283bE3f7C0245d9D259Ea82eaD7fcB8343d"
const DAIWhale_Addr = "0x7911a0e1C5909094E6138c5D7D21108AAd176ff6"
const OPWhale_Addr = "0x82326a9E6BD66e51a4c2c29168B10A1853Fc9Af7"
const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const DAI_Addr = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"
const wETH_Addr = "0x4200000000000000000000000000000000000006"
const soUSDC_Addr = "0xEC8FEa79026FfEd168cCf5C627c7f486D77b765F"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const COMPTROLLER_Addr = "0x60cf091cd3f50420d50fd7f707414d0df4751c58"
const USDCPriceFeed_Addr = "0x16a9fa2fda030272ce99b29cf780dfa30361e0f3"
const YVUSDC_Addr = "0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2"
const YVDAI_Addr = "0x65343F414FFD6c97b0f6add33d16F6845Ac22BAc"
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const StakingRewards_YVUSDC_Addr = "0xB2c04C55979B6CA7EB10e666933DE5ED84E6876b"
const StakingRewards_YVDAI_Addr = "0xf8126EF025651E1B313a6893Fcf4034F4F4bD2aA"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

/* Swap Params */

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "200" // 2%
const wait = "12" // 12 seconds
const poolFee = "3000" // 0.3%

describe("Test migrations", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const whitelister = accounts[1]
        const backupOwner = accounts[2]
        const feeCollector = accounts[3]
        const signer = await ethers.provider.getSigner(0)
        const whaleUSDCSigner = await ethers.getImpersonatedSigner(USDCWhale_Addr)
        const whaleDAISigner = await ethers.getImpersonatedSigner(DAIWhale_Addr)
        const whaleOPSigner = await ethers.getImpersonatedSigner(OPWhale_Addr)

        // Deploy soUSDC wrapper
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

        // Deploy yvUSDC wrapper
        const WYVUSDC = await ethers.getContractFactory("YearnV2ERC4626Reinvest")
        const wyvUSDC = await WYVUSDC.deploy(
            YVUSDC_Addr,
            YVOP_Addr,
            StakingRewards_YVUSDC_Addr,
            NULL_Addr,
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

        // Deploy yvDAI wrapper
        const WYVDAI = await ethers.getContractFactory("YearnV2ERC4626Reinvest")
        const wyvDAI = await WYVDAI.deploy(
            YVDAI_Addr,
            YVOP_Addr,
            StakingRewards_YVDAI_Addr,
            NULL_Addr,
            DAI_Addr, // want
            getRewardMin,
            amountInMin,
            slippage,
            wait,
            poolFee,
            {gasLimit: "30000000"}
        )
        await wyvDAI.waitForDeployment()
        console.log("wyvDAI deployed: ", await wyvDAI.getAddress())

        // Deploy coUSD
        const FITOKEN = await ethers.getContractFactory("COFIRebasingToken")
        const coUSD = await FITOKEN.deploy(
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

        // Set Diamond address in coUSD contract
        await coUSD.setApp(await diamond.getAddress())
        console.log("Diamond address set in coUSD")

        // Set Diamond as authorized in wrappers
        await wsoUSDC.setAuthorized((await diamond.getAddress()), "1")
        await wyvUSDC.setAuthorized((await diamond.getAddress()), "1")
        await wyvDAI.setAuthorized((await diamond.getAddress()), "1")

        // Set route for wsoUSDC
        await wsoUSDC.setRoute("3000", wETH_Addr, "500")
        // { Check for already deployed Sonne wrapper contracts }

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
       
        // coETH and coBTC not required for this test.
        const initArgs = [{
            coUSD:  await coUSD.getAddress(),
            coETH:  NULL_Addr,
            coBTC:  NULL_Addr,
            vUSDC:  await wsoUSDC.getAddress(),
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

        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)

        /* Admin to enable migrations (demonstrate required actions to amend live app) */
        // Reset coUSD, coETH, and coBTC buffers to 0.
        await cofiMoney.setBuffer(await coUSD.getAddress(), "0")
        // { Repeat for coETH and coBTC }
        // Set buffers for underlying.
        await cofiMoney.setBuffer(DAI_Addr, ethers.parseEther('10')) // 10 DAI
        await cofiMoney.setBuffer(USDC_Addr, "10000000") // 10 USDC
        // { Repeat for wETH, and wBTC}
        // Set decimals
        await cofiMoney.setDecimals(DAI_Addr, "18")
        // { USDC, wETH and wBTC decimals already set }
        // Set 'harvestable'
        // { Already enabled for wsoBTC }
        await cofiMoney.setHarvestable(await wyvUSDC.getAddress(), '1')
        await cofiMoney.setHarvestable(await wyvDAI.getAddress(), '1')
        console.log("Set harvestable")

        /* Obtain funds */
        const whaleUSDC = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(whaleUSDCSigner)
        const whaleDAI = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(whaleDAISigner)
        await whaleUSDC.transfer(await diamond.getAddress(), "30000000") // 30 USDC to app.
        console.log("Transferred 30 USDC")
        await whaleDAI.transfer(await diamond.getAddress(), ethers.parseEther('30')) // 30 DAI to app.
        console.log("Transferred 30 DAI")
        await whaleUSDC.transfer(await owner.getAddress(), "1000000000") // 1,000 USDC to owner.
        console.log("Transferred 1,000 USDC")
        await whaleDAI.transfer(await owner.getAddress(), ethers.parseEther('1000')) // 1,000 DAI to owner.
        console.log("Transferred 1,000 DAI")
        console.log('Obtained funds')
        /* Get underlying contracts */
        const usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(signer)
        const dai = (await ethers.getContractAt(DAI_ABI, DAI_Addr)).connect(signer)
        console.log("User USDC bal ", await usdc.balanceOf(await owner.getAddress()))
        // Deposit original
        await dai.approve(await diamond.getAddress(), ethers.parseEther('1000'))
        await usdc.approve(await diamond.getAddress(), "1000000000")
        await cofiMoney.underlyingToCofi(
            "500000000", // 500 USDC
            ethers.parseEther('497.5'), // 497.5 USDC [0.5% slippage]
            await coUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t0 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))
        console.log("t0 App wsoUSDC bal: ", await wsoUSDC.balanceOf(await diamond.getAddress()))

        // Set up executable harvest
        const whaleOP = (await ethers.getContractAt(OP_ABI, OP_Addr)).connect(whaleOPSigner)
        await whaleOP.transfer(await wsoUSDC.getAddress(), "100000000000000000000") // 100 OP
        console.log("Transferred OP to wsoUSDC contract")

        // Rebase
        await cofiMoney.rebase(await coUSD.getAddress())
        console.log("t1 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        console.log("t1 Fee Collector coUSD bal: ", await coUSD.balanceOf(await feeCollector.getAddress()))

        return { owner, wsoUSDC, wyvUSDC, wyvDAI, usdc, dai, cofiMoney, coUSD }
    }

    it("Should migrate from wsoUSDC to wyvUSDC", async function() {

        const { owner, wsoUSDC, wyvUSDC, cofiMoney, coUSD, usdc } = await loadFixture(deploy)

        await cofiMoney.migrate(await coUSD.getAddress(), await wyvUSDC.getAddress())

        console.log("t2 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        // Diamond USDC bal
        console.log("t2 App USDC bal: ", await usdc.balanceOf(await cofiMoney.getAddress()))
        console.log("t2 App wsoUSDC bal: ", await wsoUSDC.balanceOf(await cofiMoney.getAddress()))
        console.log("t2 App wyvUSDC bal: ", await wyvUSDC.balanceOf(await cofiMoney.getAddress()))

        // Do 2nd deposit with new vault integrated.
        await cofiMoney.underlyingToCofi(
            "500000000", // 500 USDC
            ethers.parseEther('497.5'), // 497.5 coUSD [0.5% slippage]
            await coUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t2 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
    })

    it("Should migrate from wsoUSDC to wyvDAI", async function() {

        const { owner, wsoUSDC, wyvDAI, cofiMoney, coUSD, usdc, dai } = await loadFixture(deploy)

        await cofiMoney.migrate(await coUSD.getAddress(), await wyvDAI.getAddress())

        console.log("t2 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
        // Diamond USDC bal
        console.log("t2 App USDC bal: ", await usdc.balanceOf(await cofiMoney.getAddress()))
        console.log("t2 App DAI bal: ", await dai.balanceOf(await cofiMoney.getAddress()))
        console.log("t2 App wsoUSDC bal: ", await wsoUSDC.balanceOf(await cofiMoney.getAddress()))
        console.log("t2 App wyvDAI bal: ", await wyvDAI.balanceOf(await cofiMoney.getAddress()))

        // Do 2nd deposit with new vault integrated.
        await cofiMoney.underlyingToCofi(
            ethers.parseEther('500'), // 500 DAI
            ethers.parseEther('497.5'), // 497.5 coUSD [0.5% slippage]
            await coUSD.getAddress(),
            await owner.getAddress(),
            await owner.getAddress(),
            NULL_Addr
        )
        console.log("t2 User coUSD bal: ", await coUSD.balanceOf(await owner.getAddress()))
    })
})
