require("@nomicfoundation/hardhat-toolbox");
require("hardhat-diamond-abi");
require("dotenv").config();

const { INFURA_API_KEY, INFURA_API_KEY_2, ALCHEMY_API_KEY, ETH_SCAN_API_KEY, POLY_SCAN_API_KEY, 
  PRIV_KEY, PRIV_KEY_2, PRIV_KEY_3, OPT_SCAN_API_KEY, ANKR_API_KEY, ARB_SCAN_API_KEY, AVAX_SCAN_API_KEY } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000
      },
      evmVersion: 'paris',
      viaIR: true
    }
  },
  diamondAbi: {
    name: "COFIMoney",
    // name: "COFIToken",
    include: ["Facet"],
    // include: ["Token"],
    // exclude: ["Token"],
    strict: false
  },
  networks: {
    ethereum: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [`${PRIV_KEY}`]
    },
    optimisticEthereum: {
      // url: `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      url: `https://opt-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [`${PRIV_KEY}`]
    },
    optimismGoerli: {
      url: `https://optimism-goerli.infura.io/v3/${INFURA_API_KEY_2}`,
      accounts: [`${PRIV_KEY}`],
      blockGasLimit: 30000000
    },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      // url: `https://rpc.ankr.com/eth_sepolia/${ANKR_API_KEY}`,
      accounts: [`${PRIV_KEY}`],
      // blockGasLimit: 30000000
    },
    mumbai: {
      // url: `https://polygon-mumbai.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      url: `https://polygon-mumbai.infura.io/v3/${INFURA_API_KEY_2}`,
      accounts: [`${PRIV_KEY}`]
    },
    arbitrumGoerli: {
      url: `https://arb-goerli.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [`${PRIV_KEY}`]
    },
    fuji: {
      url: `https://rpc.ankr.com/avalanche_fuji/${ANKR_API_KEY}`,
      accounts: [`${PRIV_KEY}`]
    },
    hardhat: {
      // forking: {
      //   url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`
      // },
      // forking: {
      //   url: `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      // },
      forking: {
        url: `https://opt-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`
      }
    }
  },
  etherscan: {
    apiKey: {
      optimisticEthereum: `${OPT_SCAN_API_KEY}`,
      sepolia: `${ETH_SCAN_API_KEY}`,
      polygonMumbai: `${POLY_SCAN_API_KEY}`,
      arbitrumGoerli: `${ARB_SCAN_API_KEY}`,
      avalancheFujiTestnet: `${AVAX_SCAN_API_KEY}`
    }
  },
  mocha: {
    timeout: 200000
  }
};