/* global ethers */

const { getSelectors, FacetCutAction } = require('../scripts/libs/diamond.js')
const { ethers } = require('hardhat')
const helpers = require('@nomicfoundation/hardhat-network-helpers');

/* Optimism */

const USDC_Addr = '0x7F5c764cBc14f9669B88837ca1490cCa17c31607'
const wETH_Addr = '0x4200000000000000000000000000000000000006'
const wBTC_Addr = '0x68f180fcCe6836688e9084f035309E29Bf0A2095'
const OP_Addr = "0x4200000000000000000000000000000000000042"
const COMPTROLLER_Addr = "0x60cf091cd3f50420d50fd7f707414d0df4751c58"
const BTCPriceFeed_Addr = "0xd702dd976fb76fffc2d3963d037dfdae5b04e593"
const wmooExactlyUSDC_Addr = '0x3a524ed2846C57f167a9284a74E0Fd04E2295786'
const wmooExactlyETH_Addr = '0x983Cb232571dE5B3fcaB42Ef0a42594cE7772ced'
const soWBTC_Addr = '0x33865E09A572d4F1CC4d75Afc9ABcc5D3d4d867D'

async function main() {

    const accounts = await ethers.getSigners()
    const owner = accounts[0]
    const signer = await ethers.provider.getSigner(0)
    const whitelister = '0x18c584492AC73182A7Bc0f89d38393f9b97d5258'
    const backupOwner = '0x79b68a8C62AA0FEdA39d08E4c6755928aFF576C5'
    const feeCollector = '0x0231c56e6Ee4257E1F79625c8bCEc746964801Aa'

    console.log(await helpers.time.latestBlock())

    /* Deploy COFI tokens */
    const COFITOKEN = await ethers.getContractFactory("COFIRebasingToken")
    const coUSD = await COFITOKEN.deploy(
        "COFI Dollar",
        "coUSD"
    )
    await coUSD.waitForDeployment()
    const coUSDAddr = await coUSD.getAddress()
    console.log("coUSD deployed: ", coUSDAddr)
    const coETH = await COFITOKEN.deploy(
        "COFI Ethereum",
        "coETH"
    )
    await coETH.waitForDeployment()
    const coETHAddr = await coETH.getAddress()
    console.log("coETH deployed: ", coETHAddr)
    const coBTC = await COFITOKEN.deploy(
        "COFI Bitcoin",
        "coBTC"
    )
    await coBTC.waitForDeployment()
    const coBTCAddr = await coBTC.getAddress()
    console.log("coBTC deployed: ", coBTCAddr)

    /* Depoly wrapper(s) - only one to begin with */
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
    const wsoBTCAddr = await wsoBTC.getAddress()
    console.log("Deployed wsoBTC to: ", wsoBTCAddr)

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
    const diamondAddr = await diamond.getAddress()
    console.log("Diamond deployed: ", diamondAddr)

    // Set Diamond address in COFIRebasingToken contracts.
    await coUSD.setApp(diamondAddr)
    console.log("Diamond address set in coUSD")
    await coETH.setApp(diamondAddr)
    console.log("Diamond address set in coETH")
    await coBTC.setApp(diamondAddr)
    console.log("Diamond address set in coBTC")

    // Deploy Point token
    const Point = await ethers.getContractFactory("PointToken")
    const point = await Point.deploy(
        'COFI Point',
        'COFI',
        diamondAddr,
        [coUSDAddr, coETHAddr, coBTCAddr]
    )
    await point.waitForDeployment()
    console.log("Point token depolyed: ", await point.getAddress())

    // Set authorized in wsoBTC contract
    await wsoBTC.setAuthorized(diamondAddr, '1')

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
        coUSD:  coUSDAddr,
        coETH:  coETHAddr,
        coBTC:  coBTCAddr,
        vUSDC:  wmooExactlyUSDC_Addr, // Already deployed
        vETH:   wmooExactlyETH_Addr, // Already deployed
        vBTC:   wsoBTCAddr,
        USDC:   USDC_Addr,
        wETH:   wETH_Addr,
        wBTC:   wBTC_Addr,
        roles: [
            whitelister,
            backupOwner,
            feeCollector
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
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});