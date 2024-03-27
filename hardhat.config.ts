import "dotenv/config"
import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "hardhat-gas-reporter"

const config: HardhatUserConfig = {
  solidity: { compilers: [{ version: "0.8.20" }, { version: "0.4.18" }] },
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
}

export default config
