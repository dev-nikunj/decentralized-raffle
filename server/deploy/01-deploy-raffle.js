const { subscribe } = require("diagnostics_channel");

const { ethers } = require("hardhat");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
const { network } = require("hardhat");
const FUND_AMOUNT = ethers.parseEther("1");
module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log, get } = deployments;
  const { deployer } = await getNamedAccounts();
  let vrfCoordinatorV2Address;
  const chainId = network.config.chainId;

  /**following is for the local network */

  if (developmentChains.includes(network.name)) {
    // const VRFCoordinatorV2Mock = await ethers.getContract(
    //   "VRFCoordinatorV2Mock",
    //   deployer
    // );

    // vrfCoordinatorV2Address = VRFCoordinatorV2Mock.address;
    const vrfCoordinatorV2MockDeployment = await get("VRFCoordinatorV2Mock");
    vrfCoordinatorV2Address = vrfCoordinatorV2MockDeployment.address;
    const vrfCoordinatorV2Mock = await ethers.getContractAt(
      "VRFCoordinatorV2Mock",
      vrfCoordinatorV2Address
    );

    const transactionResponse = await vrfCoordinatorV2Mock.createSubscription();
    const transactionReceipt = await transactionResponse.wait(1);
    // console.log("transactionReceipt", transactionReceipt.logs[0]);

    // this would come from the mock contract where the event is emitted just after creating subscription
    // var subscriptionId = transactionReceipt.events[0].args.subId;
    subscriptionId = transactionReceipt.logs[0].topics[1];
    await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, FUND_AMOUNT);
  } else {
    vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"];
    var subscriptionId = networkConfig[chainId]["subscriptionId"];
  }

  const gasLane = networkConfig[chainId]["gasLane"];
  const entranceFee = networkConfig[chainId]["entranceFee"];
  const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"];
  const interval = networkConfig[chainId]["interval"];

  const args = [
    vrfCoordinatorV2Address,
    subscriptionId,
    gasLane,
    entranceFee,
    callbackGasLimit,
    interval,
  ];

  console.log("deployer", deployer);
  //deploy
  const raffle = await deploy("Raffle", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });

  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Verifying.... at: ", raffle.address);
    await verify(raffle.address, args);
  }
};

module.exports.tags = ["all", "raffle"];
