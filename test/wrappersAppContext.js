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

/* Yearn Swap Params */

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "200" // 2%
const wait = "12" // 12 seconds
const poolFee = "3000" // 0.3%

// Note actual deployment may have to be partitioned into smaller steps

describe("Test wrappers in app context", function() {

    async function deploy() {

        const accounts = await ethers.getSigners()
        const owner = accounts[0]
        const backupOwner = accounts[1]
        const whitelister = accounts[2]
        const feeCollector = accounts[3]

        const signer = (await ethers.provider.getSigner(0))

        console.log(await helpers.time.latestBlock())

        /* Deploy wrappers */

        const WYVUSDC = await ethers.getContractFactory("YearnZapReinvestWrapper")
        const wyvUSDC = await WYVUSDC.deploy(
            YVUSDC_Addr,
            YVOP_Addr,
            StakingRewards_YVUSDC_Addr,
            "0x0000000000000000000000000000000000000000",
            USDC_Addr,
            getRewardMin,
            amountInMin,
            slippage,
            wait,
            poolFee,
            {gasLimit: "30000000"}
        )
        await wyvUSDC.waitForDeployment()
        console.log("wyvUSDC deployed: ", await wyvUSDC.getAddress())
    
        const WYVETH = await ethers.getContractFactory("YearnZapReinvestWrapper")
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

        const WSOBTC = await ethers.getContractFactory("CompoundV2ERC4626Wrapper")
        const wsoBTC = await WSOBTC.deploy(
            WBTC_Addr,
            OP_Addr,
            SOWBTC_Addr,
            COMPTROLLER_Addr,
            "0xd702dd976fb76fffc2d3963d037dfdae5b04e593", // BTC price feed
            (await owner.getAddress()),
            "1000000000000000000", // amountInMin = 1 OP
            "200", // slippage = 2%
            "12" // wait = 12 seconds
        )
        await wsoBTC.waitForDeployment();
        console.log("wsoBTC deployed: " + await wsoBTC.getAddress())

        /* Deploy COFI tokens */

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

        const FIBTC = await ethers.getContractFactory("FiToken")
        const fiBTC = await FIBTC.deploy(
            "COFI Bitcoin",
            "fiBTC"
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
        await fiUSD.setDiamond(await diamond.getAddress())
        await fiETH.setDiamond(await diamond.getAddress())
        await fiBTC.setDiamond(await diamond.getAddress())

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
        await facet.deployed()
        console.log(`${FacetName} deployed: ${facet.address}`)
        cut.push({
            facetAddress: facet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(facet)
        })
        }
        
        const initArgs = [{
            fiUSD:  (await fiUSD.getAddress()),
            fiETH:  (await fiETH.getAddress()),
            fiBTC:  (await fiBTC.getAddress()),
            vUSDC:  (await wyvUSDC.getAddress()),
            vETH:   (await wyvETH.getAddress()),
            vBTC:   (await wsoBTC.getAddress()),
            USDC:   USDC_Addr,
            wETH:   WETH_Addr,
            wBTC:   WBTC_Addr,
            roles:
                [
                    (await whitelister.getAddress()),
                    (await backupOwner.getAddress()),
                    (await feeCollector.getAddress())
                ]
        }]
        
        // Upgrade diamond with facets
        console.log('')
        console.log('Diamond Cut:', cut)
        const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address)
        let tx
        let receipt
        // Call to init function
        let functionCall = diamondInit.interface.encodeFunctionData('init', initArgs)
        tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall)
        console.log('Diamond cut tx: ', tx.hash)
        receipt = await tx.wait()
        if (!receipt.status) {
        throw Error(`Diamond upgrade failed: ${tx.hash}`)
        }
        console.log('Completed diamond cut')

        // Authorize Diamond to interact with wrappers
        await wyvUSDC.setAuthorized(await diamond.getAddress(), "1")
        await wyvETH.setAuthorized(await diamond.getAddress(), "1")
        await wsoBTC.setAuthorized(await diamond.getAddress(), "1")

        
    }
})