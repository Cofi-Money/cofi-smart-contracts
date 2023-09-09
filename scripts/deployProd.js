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
const soWBTC_Addr = '0x33865E09A572d4F1CC4d75Afc9ABcc5D3d4d867D'
const YVOP_Addr = "0x7D2382b1f8Af621229d33464340541Db362B4907"
const YVDAI_Addr = "0x65343F414FFD6c97b0f6add33d16F6845Ac22BAc"
const YVETH_Addr = "0x5B977577Eb8a480f63e11FC615D6753adB8652Ae"
const StakingRewards_YVDAI_Addr = "0xf8126EF025651E1B313a6893Fcf4034F4F4bD2aA"
const StakingRewards_YVETH_Addr = "0xE35Fec3895Dcecc7d2a91e8ae4fF3c0d43ebfFE0"

/* Yearn Swap Params */

const getRewardMin = "1000000000000000000" // 1 OP
const amountInMin = "1000000000000000000" // 1 OP
const slippage = "1500" // 15%
const wait = "12" // 12 seconds
const poolFee = "3000" // 0.3%

async function main() {

    const accounts = await ethers.getSigners()
    const owner = accounts[0]
    const signer = await ethers.provider.getSigner(0)
    const whitelister = '0x18c584492AC73182A7Bc0f89d38393f9b97d5258'
    const backupOwner = '0x79b68a8C62AA0FEdA39d08E4c6755928aFF576C5'
    const feeCollector = '0x0231c56e6Ee4257E1F79625c8bCEc746964801Aa'

    // /* Deploy COFI tokens */
    // const COFITOKEN = await ethers.getContractFactory("COFIRebasingToken")
    // const coUSD = await COFITOKEN.deploy(
    //     "COFI Dollar",
    //     "coUSD"
    // )
    // await coUSD.waitForDeployment()
    // const coUSDAddr = await coUSD.getAddress()
    // console.log("coUSD deployed: ", coUSDAddr)
    // const coETH = await COFITOKEN.deploy(
    //     "COFI Ethereum",
    //     "coETH"
    // )
    // await coETH.waitForDeployment()
    // const coETHAddr = await coETH.getAddress()
    // console.log("coETH deployed: ", coETHAddr)
    // const coBTC = await COFITOKEN.deploy(
    //     "COFI Bitcoin",
    //     "coBTC"
    // )
    // await coBTC.waitForDeployment()
    // const coBTCAddr = await coBTC.getAddress()
    // console.log("coBTC deployed: ", coBTCAddr)
    // const coOP = await COFITOKEN.deploy(
    //     "COFI Optimism",
    //     "coOP"
    // )
    // await coOP.waitForDeployment()
    // const coOPAddr = await coOP.getAddress()
    // console.log("coOP deployed: ", coOPAddr)

    const coUSD = await ethers.getContractAt(
        "COFIRebasingToken",
        "0x8924ad39beEB4f8B778A1CcA6CB7CE89788eA895"
    )
    const coUSDAddr = "0x8924ad39beEB4f8B778A1CcA6CB7CE89788eA895"
    const coETH = await ethers.getContractAt(
        "COFIRebasingToken",
        "0xd371a070E505e3d553B8382A7874D177A1EE23A3"
    )
    const coETHAddr = "0xd371a070E505e3d553B8382A7874D177A1EE23A3"
    const coBTC = await ethers.getContractAt(
        "COFIRebasingToken",
        "0x0395F6F10C8594Cef335E4DfB898bE37F766cBf2"
    )
    const coBTCAddr = "0x0395F6F10C8594Cef335E4DfB898bE37F766cBf2"
    const coOP = await ethers.getContractAt(
        "COFIRebasingToken",
        "0xa12a6f1e941919Fc4F880173017152497b251B57"
    )
    const coOPAddr = "0xa12a6f1e941919Fc4F880173017152497b251B57"

    /* Depoly Wrappers */
    // const WYVTKNSTK = await ethers.getContractFactory("YearnV2StakingRewards")
    // const wyvDAI = await WYVTKNSTK.deploy(
    //     YVDAI_Addr,
    //     YVOP_Addr,
    //     StakingRewards_YVDAI_Addr,
    //     "0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6", // DAI price feed
    //     getRewardMin,
    //     amountInMin,
    //     slippage,
    //     wait,
    //     poolFee,
    //     "1",
    //     // {gasLimit: "30000000"}
    // )
    // await wyvDAI.waitForDeployment()
    // const wyvDAIAddr = await wyvDAI.getAddress()
    // console.log("wyvDAI deployed: ", wyvDAIAddr)

    const wyvDAI = await ethers.getContractAt(
        "YearnV2StakingRewards",
        "0x167d58094cA42c12aF081d509C1fa2480ae59196"
    )
    const wyvDAIAddr = "0x167d58094cA42c12aF081d509C1fa2480ae59196"

    // const wyvETH = await WYVTKNSTK.deploy(
    //     YVETH_Addr,
    //     YVOP_Addr,
    //     StakingRewards_YVETH_Addr,
    //     "0x13e3Ee699D1909E989722E753853AE30b17e08c5", // ETH price feed
    //     getRewardMin,
    //     amountInMin,
    //     slippage,
    //     wait,
    //     poolFee,
    //     "1",
    //     // {gasLimit: "30000000"}
    // )
    // await wyvETH.waitForDeployment()
    // const wyvETHAddr = await wyvETH.getAddress()
    // console.log("wyvETH deployed: ", wyvETHAddr)

    const wyvETH = await ethers.getContractAt(
        "YearnV2StakingRewards",
        "0x0b840B4A75b83077F9FC66F64c33739c647D352c"
    )
    const wyvETHAddr = "0x0b840B4A75b83077F9FC66F64c33739c647D352c"

    // const WSOBTC = await ethers.getContractFactory("CompoundV2Reinvest")
    // const wsoBTC = await WSOBTC.deploy(
    //     wBTC_Addr,
    //     OP_Addr,
    //     soWBTC_Addr,
    //     "0xd702dd976fb76fffc2d3963d037dfdae5b04e593", // BTC price feed
    //     amountInMin,
    //     slippage,
    //     wait,
    //     // {gasLimit: "30000000"}
    // )
    // await wsoBTC.waitForDeployment()
    // const wsoBTCAddr = await wsoBTC.getAddress()
    // console.log("Deployed wsoBTC to: ", wsoBTCAddr)
    const wsoBTC = await ethers.getContractAt(
        "CompoundV2Reinvest",
        "0x6Fd0CCe7fcA444b8FC420E165ED281C513976747"
    )
    const wsoBTCAddr = "0x6Fd0CCe7fcA444b8FC420E165ED281C513976747"

    // No price feed for OP wrapper as rewards are already OP.
    // const WYVTKN = await ethers.getContractFactory("YearnV2")
    // const wyvOP = await WYVTKN.deploy(
    //     YVOP_Addr,
    //     // {gasLimit: "30000000"}
    // )
    // await wyvOP.waitForDeployment()
    // const wyvOPAddr = await wyvOP.getAddress()
    // console.log("wyvOP deployed: ", wyvOPAddr)
    const wyvOP = await ethers.getContractAt(
        "YearnV2",
        "0xD8D50DE6222f35c7B212ff174847529E41B8A5Fb"
    )
    const wyvOPAddr = "0xD8D50DE6222f35c7B212ff174847529E41B8A5Fb"

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
    await coOP.setApp(diamondAddr)
    console.log("Diamond address set in coOP")

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
        coUSD:  coUSDAddr,
        coETH:  coETHAddr,
        coBTC:  coBTCAddr,
        coOP:   coOPAddr,
        vUSD:   wyvDAIAddr,
        vETH:   wyvETHAddr,
        vBTC:   wsoBTCAddr,
        vOP:    wyvOPAddr,
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

    // Deploy Point token
    const Point = await ethers.getContractFactory("PointToken")
    const point = await Point.deploy(
        'COFI Point',
        'COFI',
        diamondAddr,
        [coUSDAddr, coETHAddr, coBTCAddr, coOPAddr]
    )
    await point.waitForDeployment()
    console.log("Point token depolyed: ", await point.getAddress())

    // Wrapper set up.
    await wyvETH.setAuthorized(diamondAddr, "1")
    await wyvETH.setRewardShareReceiver(diamondAddr)
    await wyvDAI.setAuthorized(diamondAddr, "1")
    await wyvDAI.setRewardShareReceiver(diamondAddr)
    await wsoBTC.setAuthorized(diamondAddr, "1")
    await wyvOP.setAuthorized(diamondAddr, "1")
    await wyvOP.setFlushReceiver(diamondAddr)
    console.log("Authorized Diamond interaction with wrappers")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});