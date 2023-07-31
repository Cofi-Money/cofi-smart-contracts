/* global ethers */

const { getSelectors, FacetCutAction } = require("../scripts/libs/diamond.js")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-network-helpers");

/* Optimism */

const USDC_ABI = require("./abi/USDC.json")
const OP_ABI = require("./abi/OP.json")
const USDC_Addr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
const OP_Addr = "0x4200000000000000000000000000000000000042"
const YVUSDC_Addr = "0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2"
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const StakingRewards_YVUSDC_Addr = "0xB2c04C55979B6CA7EB10e666933DE5ED84E6876b"
const NULL_Addr = "0x0000000000000000000000000000000000000000"

/* Yearn Swap Params */

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "200" // 2%
const wait = "12" // 12 seconds
const poolFee = "3000" // 0.3%

const whaleUsdcEth = "0xee55c2100C3828875E0D65194311B8eF0372C6d9"

describe("Test yield and points tracking", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const backupOwner = accounts[1]
        const whitelister = accounts[2]
        const feeCollector = accounts[3]

        const signer = await ethers.provider.getSigner(0)
        const backupSigner = await ethers.provider.getSigner(1)
        const wueSigner = await ethers.getImpersonatedSigner(whaleUsdcEth)

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

        /* Deploy COFI tokens */

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

        // Set Diamond address in FiToken contracts.
        await fiUSD.setApp(await diamond.getAddress())
        console.log("Diamond address set in fiUSD")
        
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
            fiUSD:  await fiUSD.getAddress(),
            vUSDC:  await wyvUSDC.getAddress(),
            USDC:   USDC_Addr,
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

        // Authorize Diamond to interact with wrappers.
        await wyvUSDC.setAuthorized(await diamond.getAddress(), "1")
        // Set Diamond as receiver for reward deposits.
        await wyvUSDC.setRewardShareReceiver(await diamond.getAddress())

        // Deploy Point Token contract
        const Point = await ethers.getContractFactory('PointToken')
        const point = await Point.deploy(
            "COFI Point",
            "COFI",
            await diamond.getAddress(),
            [await fiUSD.getAddress()]
        )
        await point.waitForDeployment()
        console.log('Point token deployed: ', await point.getAddress())

        /* Whitelist user */
        const cofiMoney = (await ethers.getContractAt('COFIMoney', await diamond.getAddress())).connect(signer)
        await cofiMoney.setWhitelist((await owner.getAddress()), "1")
        console.log("Whitelisted user")
        await cofiMoney.setWhitelist((await backupOwner.getAddress()), "1")
        console.log("Whitelisted secondary user")

        /* Transfer user assets */
        const wue_usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(wueSigner)
        await wue_usdc.transfer((await owner.getAddress()), "1000000000") // 1,000 USDC
        console.log("Transferred USDC to user")
        await wue_usdc.transfer((await backupOwner.getAddress()), "1010000000") // 1,010 USDC
        console.log("Transferred USDC to 2nd user")

        /* Initial deposits */
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
        console.log("t0 Owner fiUSD bal: ", await fiUSD.balanceOf(await owner.getAddress()))
        console.log("t0 Fee Collector fiUSD bal: ", await fiUSD.balanceOf(await feeCollector.getAddress()))

        // Calling getAddress does not work
        const backupOwnerAddr = await backupOwner.getAddress()
        console.log("t0 ERC20 points: " + await point.balanceOf(await owner.getAddress()))
        console.log("t0 App points: " + await cofiMoney.getPoints(await owner.getAddress(), [await fiUSD.getAddress()]))
        console.log("t0 yield earned: " + await fiUSD.getYieldEarned(await owner.getAddress()))
        console.log("t0 ERC20 points 2nd user: " + await point.balanceOf(backupOwnerAddr))
        console.log("t0 App points 2nd user: " + await cofiMoney.getPoints(backupOwnerAddr, [await fiUSD.getAddress()]))
        console.log("t0 yield earned 2nd user: " + await fiUSD.getYieldEarned(backupOwnerAddr))

        /* Set up executable yield distribution */
        await wue_usdc.transfer(await wyvUSDC.getAddress(), "10000000") // 10 USDC
        console.log("Transferred USDC to wrapper")

        return {
            owner, feeCollector, signer, wueSigner, backupSigner,
            backupOwnerAddr, wyvUSDC, fiUSD, usdc, cofiMoney, point
        }
    }

    it("Should track points and yield accurately", async function() {

        const { owner, cofiMoney, fiUSD, backupSigner, backupOwnerAddr, point, wue_usdc, wyvUSDC } = await loadFixture(deploy)

        // Performs flush operation.
        await cofiMoney.rebase(await fiUSD.getAddress())

        // Should only show for first user as second is yet to deposit.
        console.log("t1 ERC20 points: " + await point.balanceOf(await owner.getAddress()))
        console.log("t1 App points: " + await cofiMoney.getPoints(await owner.getAddress(), [await fiUSD.getAddress()]))
        console.log("t1 yield earned: " + await fiUSD.getYieldEarned(await owner.getAddress()))
        console.log("t1 ERC20 points 2nd user: " + await point.balanceOf(backupOwnerAddr))
        console.log("t1 App points 2nd user: " + await cofiMoney.getPoints(backupOwnerAddr, [await fiUSD.getAddress()]))
        console.log("t1 yield earned 2nd user: " + await fiUSD.getYieldEarned(backupOwnerAddr))

        const _usdc = (await ethers.getContractAt(USDC_ABI, USDC_Addr)).connect(backupSigner)
        await _usdc.approve(await cofiMoney.getAddress(), "1000000000") // 1,000 USDC
        const _cofiMoney = (await ethers.getContractAt('COFIMoney', await cofiMoney.getAddress()))
            .connect(backupSigner)
        await _cofiMoney.underlyingToFi(
            "1000000000",
            "997500000000000000000", // 0.25% slippage
            await fiUSD.getAddress(),
            backupOwnerAddr,
            backupOwnerAddr,
            await owner.getAddress() // Referral
        )
        console.log("t2 fiUSD bal 2nd user: " + await fiUSD.balanceOf(backupOwnerAddr))

        console.log("t2 ERC20 points: " + await point.balanceOf(await owner.getAddress()))
        console.log("t2 App points: " + await cofiMoney.getPoints(await owner.getAddress(), [await fiUSD.getAddress()]))
        console.log("t2 yield earned: " + await fiUSD.getYieldEarned(await owner.getAddress()))
        // Should now display sign-up points for second user.
        console.log("t2 ERC20 points 2nd user: " + await point.balanceOf(backupOwnerAddr))
        console.log("t2 App points 2nd user: " + await cofiMoney.getPoints(backupOwnerAddr, [await fiUSD.getAddress()]))
        console.log("t2 yield earned 2nd user: " + await fiUSD.getYieldEarned(backupOwnerAddr))

        await _usdc.transfer(await wyvUSDC.getAddress(), "10000000") // 10 USDC
        console.log("Transferred USDC to wrapper")
        // Flush again.
        await cofiMoney.rebase(await fiUSD.getAddress())

        console.log("t3 ERC20 points: " + await point.balanceOf(await owner.getAddress()))
        console.log("t3 App points: " + await cofiMoney.getPoints(await owner.getAddress(), [await fiUSD.getAddress()]))
        console.log("t3 yield earned: " + await fiUSD.getYieldEarned(await owner.getAddress()))
        console.log("t3 ERC20 points 2nd user: " + await point.balanceOf(backupOwnerAddr))
        console.log("t3 App points 2nd user: " + await cofiMoney.getPoints(backupOwnerAddr, [await fiUSD.getAddress()]))
        console.log("t3 yield earned 2nd user: " + await fiUSD.getYieldEarned(backupOwnerAddr)) 
    })
})