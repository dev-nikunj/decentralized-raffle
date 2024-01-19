const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");

const BASE_FEE = "250000000000000000"; // ethers.utils.parseEther("0.25"); //0.25 is premium here it is the cost
const GAS_PRICE_LINK = 1e9;

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  // const args = [BASE_FEE, GAS_PRICE_LINK];

  if (chainId == 31337) {
    log("Local Network detected!! Deploying Mocks.....");

    //deploying mocks

    var mock = await deploy("VRFCoordinatorV2Mock", {
      from: deployer,
      log: true,
      args: [BASE_FEE, GAS_PRICE_LINK],
    });
  }

  log(`mocks deployed successfully..............\n }`);
  log(
    "------------------------------------------------------------------------"
  );
};

module.exports.tags = ["all", "mocks"];
