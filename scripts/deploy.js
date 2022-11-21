async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const Storage = await ethers.getContractFactory("Storage");
    const storage = await Storage.deploy();

    console.log("Storage Address:", storage.address);

    const Timelock = await ethers.getContractFactory("Timelock");
    const timelock = await Timelock.deploy();

    console.log("Timelock Address:", timelock.address);
  
    const Collaborator = await ethers.getContractFactory("Collaborator");
    const collaborator = await Collaborator.deploy();    
  
    console.log("Collaborator Address:", collaborator.address);

    const CollabGovernor = await ethers.getContractFactory("CollabGovernor");
    const collabGovernor = await CollabGovernor.deploy(collaborator.address, timelock.address);    
  
    console.log("Collaborator Governor Address:", collabGovernor.address);

    // https://docs.openzeppelin.com/defender/guide-timelock-roles#granting-a-role

    await timelock.grantRole("0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1",collabGovernor.address); //grant gov contract proposer
    await timelock.grantRole("0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63",collabGovernor.address); //grant gov contract executor
    console.log("Collaborator governor contract given roles")

    await timelock.grantRole("0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63",deployer.address); //grant deployer executor
    console.log("Deployer given executor role")

    await timelock.renounceRole("0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5", deployer.address); //renounce admin
    console.log("deployer renounces admin of timelock")

    const RewardContract = await ethers.getContractFactory("RewardContract");
    const rewardContract = await RewardContract.deploy(collaborator.address, storage.address, timelock.address);    
    console.log("Reward Contract Address:", rewardContract.address);

    await collaborator.setTargetAddress(rewardContract.address);
    await collaborator.transferOwnership(timelock.address);
    console.log("deployer renounces ownership of collaborator")
  
    

  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });