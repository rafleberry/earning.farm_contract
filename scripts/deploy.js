const { ethers, network } = require("hardhat");
const { config } = require("./config");
const { deployCrss, deployFactory, deployFarm, deployMaker, deployTaker, deployXCrss, deployReferral, deployCCrss, verifyContract, verifyUpgradeable } = require("./feature/deploy");
const {abi: abiCrss} = require("../artifacts/contracts/farm/CrssToken.sol/CrssToken.json")
const {abi: abiPair} = require("../artifacts/contracts/core/CrossPair.sol/CrossPair.json")
const {abi: abiMaker} = require("../artifacts/contracts/periphery/CrossMaker.sol/CrossMaker.json");
const { deployCCrss } = require("../test-dex/utils");
require("colors")

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Network:", network.name);

  // Quit if networks are not supported
  if (network.name !== "bsc_testnet" && network.name !== "bsc_mainnet" && network.name !== "hardhat") {
    console.log("Network name is not supported");
    return;
  }

  const conf = config.bsc_testnet;
  // const conf = config[network.name];

  const factory = await deployFactory(deployer, deployer.address);
  const factoryAddr = factory.address
  // const factoryAddr = "0xA6eB2c77D5eF18a2A1435B12dF68b7420Adb2EcF"

  
  const WBNB = await ethers.getContractFactory("WBNB");
  const wbnb = await WBNB.deploy();
  const wbnbAddr = wbnb.address
  // const newFactory = "0x74793eefDaC6B80420eb38E68E12F84462c5dA7e"
  // const factory = "0x1d29305819dD77899FC487fB65540149f9d29847"
  const maker = await deployMaker(deployer, factoryAddr, wbnbAddr);
  const makerAddr = maker.address
  // // const makerAddr = "0xEe13C45e405D67529BCf268dC59E45ccd0AD4A8C"
  // // const makerAddr = "0xD20885a5de05229F0868fc234152eC9c25e86D08"

  const taker = await deployTaker(deployer, factoryAddr, wbnbAddr);
  const takerAddr = taker.address;
  // const takerAddr = "0x8ea80638a4eF3C86bF73AeE80C4978928e3cE114";

  const crss = await deployCrss(deployer, [deployer.address, deployer.address, deployer.address], makerAddr, takerAddr)
  const crssAddr = crss.address;
  // const crssAddr = "0x813D495AD604c6E9Df23742F29A71459B124c06F"
  // Crss Proxy Addr: 0xC6C1FeFd7957051df8DEF62a1b7eB46bE10bC305

  const startBlock = await ethers.provider.getBlockNumber() + 100;
  const crssPerBlock = ethers.utils.parseEther(config.crssEmit)
  const farm = await deployFarm(deployer, crssAddr, deployer.address, makerAddr, takerAddr, crssPerBlock, startBlock)
  const farmAddr = farm.address
  // const farmAddr = "0xcFCC3F13353B35c44c40A4867ACC8388f28BF20a"
  // Farm proxy Addr: 0x6ebB31F80eE86078a0FaD7360843759A6d65F631

  const xcrss = await deployXCrss(deployer, crssAddr);
  const xCrssAddr = xcrss.address;
  // const xCrssAddr = "0xFDC97F07a4917Fc2BFd0DAEd59d2CF86d73d4dFd";
  // XCrss Proxy Address: 0x61Afa2e5411558B0E2B033d5423E10d746E98eAb

  const referral = await deployReferral(deployer)
  const referralAddr = referral.address
  // const referralAddr = "0xEd69B1357946366B7f00C33E43F6663CD303B109"
  // Referral Proxy: 0xa68C99eEEA407C6bE5c2541DB94A9E38b17826f6

  const cCrss = await deployCCrss(deployer);
  const cCrssAddr = cCrss.address;

  const MockToken = await ethers.getContractFactory("MockToken");
  mock = await MockToken.deploy("Mock", "MCK");
  console.log("- Mock token deployed: ", mock.address);

  await factory.setTaker(taker.address);
  console.log("\tTaker Set Factory: ", taker.address);

  await factory.setMaker(maker.address);
  console.log("\tMaker Set Factory: ", maker.address);

  await maker.setToken(crss.address);
  await maker.setLiquidityChangeLimit(5000); // 5%
  console.log("\tMaker set Token: ", crss.address);

  await taker.setToken(crss.address);
  await taker.setPriceChangeLimit(5000); // 5%
  console.log("\tTaker set Token:", crss.address);

  await crss.setFarm(farm.address)
  console.log("\tCrss set Farm: ", farm.address)

  await xcrss.setFarm(farm.address);
  console.log("\tXCRSS set Farm: ", xcrss.address);

  await farm.setToken(crss.address)
  console.log("\tFarm set Crss: ", crss.address)

  await farm.setXToken(xcrss.address);
  console.log("\tFarm set xCrss: ", xcrss.address)

  await farm.setCrssReferral(referral.address);
  console.log("\tFarm set Referral: ", referral.address)

  const deployerLog = { Label: "Deploying Address", Info: deployer.address };
  const deployLog = [
    {
      Label: "Deployed and Verified CrossFactory Address",
      Info: factory.address,
    },
    {
      Label: "Deployed and Verified CrossMaker Address",
      Info: maker.address,
    },
    {
      Label: "Deployed and Verified CrossTaker Address",
      Info: taker.address,
    },
    {
      Label: "Deployed and Verified CrssToken Address",
      Info: crss.address,
    },
    {
      Label: "Deployed and Verified xCrssToken Address",
      Info: xcrss.address,
    },
    {
      Label: "Deployed and Verified CrossFarm Address",
      Info: farm.address,
    },
    {
      Label: "Deployed and Verified CrossReferral Address",
      Info: referral.address,
    },
  ];

  console.table([deployerLog, ...deployLog]);
  console.log("\tFactory Code Hash: ", await factory.INIT_CODE_PAIR_HASH());

  // Run
  await tokenMint(mock, deployer.address, "Deployer", "100000000")
  const mockAmount = "10000";
  const crssAmount = "100000";
  await tokenApprove(crss, deployer, "Deployer", maker.address, "Router", crssAmount)
  await tokenApprove(mock, deployer, "Deployer", maker.address, "Router", mockAmount)

  let block = await ethers.provider.getBlock("latest");
  await maker.addLiquidityETH(
    crssAddr,
    ethers.utils.parseEther("100"),
    0,
    0,
    deployer.address,
    block.timestamp + 1000,
    {
      value: ethers.utils.parseEther("0.1")
    }
  );

  block = await ethers.provider.getBlock("latest");
  await crss.approve(taker.address, ethers.utils.parseEther("100"));
  swapAmount = 0.011;
  console.log("\tSwap Crss to BNB")
  await taker.swapExactTokensForETH(
    ethers.utils.parseEther(swapAmount.toString()),
    0,
    [crss.address, wbnb.address],
    deployer.address,
    block.timestamp + 1000
  )
  
  // await verifyContract(factoryAddr, [deployer.address])
  // await verifyContract(makerAddr, [factoryAddr, wbnbAddr])
  // await verifyContract(takerAddr, [factoryAddr, wbnbAddr])
  // await verifyUpgradeable(crssAddr)
  // await verifyUpgradeable(farmAddr)
  // await verifyUpgradeable(xCrssAddr)
  // await verifyUpgradeable(referralAddr)
  // await verifyContract(mock.address, ["Mock", "MCK"])
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

  

async function tokenMint(token, account, accountName, amount) {
  await token.mint(account, ethers.utils.parseEther(amount))
  const balance = await token.balanceOf(account)
  console.log(`\t${accountName} has ${ethers.utils.formatEther(balance)} of ${await token.name()} Token`.yellow)
}

async function tokenApprove(token, from, fromName, to, toName, amount) {
  await token.connect(from).approve(to, ethers.utils.parseEther(amount));
  const allowance = await token.allowance(from.address, to)
  console.log(`\t${fromName} approved ${ethers.utils.formatEther(allowance)} of ${await token.name()} Token to ${toName}`.yellow);
}
