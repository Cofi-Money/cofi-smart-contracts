require("@nomicfoundation/hardhat-toolbox");
require("hardhat-diamond-abi");
require("dotenv").config();

const { INFURA_API_KEY, ALCHEMY_API_KEY, PRIV_KEY, OPT_SCAN_API_KEY } = process.env;

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
    optimisticEthereum: {
      url: `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [`${PRIV_KEY}`]
    },
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`
      },
      // forking: {
      //   url: `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      // },
      // forking: {
      //   url: `https://opt-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`
      // }
    }
  },
  etherscan: {
    apiKey: {
      optimisticEthereum: `${OPT_SCAN_API_KEY}`
    }
  }
};