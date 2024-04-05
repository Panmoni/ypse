import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
// import { Contract } from "ethers";

/**
 * Deploys a contract named "YourContract" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployContracts: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network goerli`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  // Set the platformFeePercentage and penaltyPercentage values
  const platformFeePercentage = 0; // 0% platform fee percentage
  const penaltyPercentage = 5; // 5% penalty percentage

  // Deploy the ContractRegistry contract
  const registry = await deploy("ContractRegistry", {
    from: deployer,
    args: [
      "0x0000000000000000000000000000000000000000", // Placeholder for Account address
      "0x0000000000000000000000000000000000000000", // Placeholder for Offer address
      "0x0000000000000000000000000000000000000000", // Placeholder for Trade address
      "0x0000000000000000000000000000000000000000", // Placeholder for Escrow address
      "0x0000000000000000000000000000000000000000", // Placeholder for Rating address
      "0x0000000000000000000000000000000000000000", // Placeholder for Reputation address
      "0x0000000000000000000000000000000000000000", // Placeholder for Arbitration address
    ],
    log: true,
    autoMine: true,
  });

  // Deploy the Account contract
  const account = await deploy("Account", {
    from: deployer,
    args: [registry.address],
    log: true,
    autoMine: true,
  });

  // Deploy the Escrow contract
  const escrow = await deploy("Escrow", {
    from: deployer,
    args: [deployer, registry.address, platformFeePercentage, penaltyPercentage],
    log: true,
    autoMine: true,
  });

  // Deploy the Arbitration contract
  const arbitration = await deploy("Arbitration", {
    from: deployer,
    args: [deployer, registry.address],
    log: true,
    autoMine: true,
  });

  // Deploy the Trade contract
  const trade = await deploy("Trade", {
    from: deployer,
    args: [registry.address],
    log: true,
    autoMine: true,
  });

  // Deploy the Offer contract
  const offer = await deploy("Offer", {
    from: deployer,
    args: [registry.address],
    log: true,
    autoMine: true,
  });

  // Deploy the Rating contract
  const rating = await deploy("Rating", {
    from: deployer,
    args: [registry.address],
    log: true,
    autoMine: true,
  });

  // Deploy the Reputation contract
  const reputation = await deploy("Reputation", {
    from: deployer,
    args: [registry.address],
    log: true,
    autoMine: true,
  });

  // Get the deployed ContractRegistry contract
  const registryContract = await hre.ethers.getContract("ContractRegistry");

  // Update the ContractRegistry with the deployed contract addresses
  await registryContract.updateAddresses(
    account.address,
    offer.address,
    trade.address,
    escrow.address,
    rating.address,
    reputation.address,
    arbitration.address,
  );

  console.log("ContractRegistry addresses updated");
};

export default deployContracts;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags YourContract
deployContracts.tags = ["YourContract"];
