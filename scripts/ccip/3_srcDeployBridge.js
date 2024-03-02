/* global ethers */

const { ethers } = require('hardhat')

const SEPOLIA_ROUTER = "0xD0daae2231E9CB96b94C8512223533293C3693Bf"
const MUMBAI_ROUTER = "0x70499c328e1E2a3c41108bd3730F6670a44595D1"
const OPTIMISM_GOERLI_ROUTER = "0xEB52E9Ae4A9Fb37172978642d4C141ef53876f26"
const FUJI_ROUTER = "0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8"
const OP_ROUTER = "0x3206695CaE29952f4b0c22a169725a865bc8Ce0f" //v1.2
const SEPOLIA_LINK = "0x779877A7B0D9E8603169DdbD7836e478b4624789"
const MUMBAI_LINK = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"
const OPTIMISM_GOERLI_LINK = "0xdc2CC710e42857672E7907CF474a69B63B93089f"
const OP_LINK = "0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6"
const FUJI_LINK = "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846"
const MUMBAI_CHAIN_SELECTOR = "12532609583862916517"
const ARBITRUM_GOERLI_CHAIN_SELECTOR = "6101244977088475029"
const FUJI_CHAIN_SELECTOR = "14767482510784806043"
const POLY_CHAIN_SELECTOR = "4051577828743386545"

async function main() {

    const BridgeEntry = await ethers.getContractFactory("CofiBridge")
    const bridgeEntry = await BridgeEntry.deploy(
        OP_ROUTER, // src
        OP_LINK, // src
        "0x8924ad39beEB4f8B778A1CcA6CB7CE89788eA895", // cofi X
        "0x901327f9B46dF1A8B72dD202dDFC4c05DE8fe599", // vault X
        POLY_CHAIN_SELECTOR,
        "0x746C78bCB4106D2a37ebAD36552c1249b2Bd41bB", // destShare X
        "0x82E55a92611E1D8319bBB63e154AA0833755c819" // exit bridge X
    )
    await bridgeEntry.waitForDeployment()
    console.log("Cofi Bridge deployed: ", await bridgeEntry.getAddress())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});