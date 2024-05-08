import "dotenv/config";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import "@typechain/hardhat";
import 'hardhat-contract-sizer';  // Make sure this is imported

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200 // Configure this number based on the expected transaction count
          }
        }
      },
      {
        version: "0.4.18",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200 // Same as above, adjust based on your needs
          }
        }
      }
    ]
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 21,
    enabled: true,
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/54f4426eea6944b18e3e33b888e4949f`,
      accounts: ['0x4624deb6f549092de32f9b96e1eeef9e8b5d289e61305671e3ba704ac927368f'],
    },
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v6",
  },
  contractSizer: {
    runOnCompile: true,  // Automatically run contract-sizer after every compilation
    strict: false,       // Set to true if you want to fail compilation when a contract exceeds 24kB
    alphaSort: true,     // Alphabetically sort the contract names in the output
    disambiguatePaths: false,
  },
};

export default config;
