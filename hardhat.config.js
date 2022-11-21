/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require('dotenv').config()
 require("@nomiclabs/hardhat-etherscan");
 require("@nomiclabs/hardhat-waffle");
 require("hardhat-gas-reporter");

module.exports = {
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 500,
      },
    },
  }, 
  networks: {
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA}`, //Infura url with projectId
      accounts: [process.env.PRIVATE_KEY] // add the account that will deploy the contract (private key)
     },
     mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA}`, // or any other JSON-RPC provider
      accounts: [process.env.PRIVATE_KEY]
    }
   },
   etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN
  }
};
