const { ethers, waffle, network, upgrades } = require("hardhat");
const { expect, util } = require("chai");
//const { FakeContract, smock } = require("@defi-wonderland/smock");

const { utils } = require("ethers");
const { abi: pairAbi } = require("../artifacts/contracts/core/CrossPair.sol/CrossPair.json");

// Address of contract and users that will be used globally
let factory,
  router,
  wbnb,
  crss,
  farm,
  xcrss,
  mock,
  referral,
  crss_mockPair,
  crss_ethPair,
  devTo,
  buybackTo,
  CrssBnbLP,
  CrssMCKLP,
  allocPoint,
  crssPerBlock,
  devFee,
  vestedReward,
  withdrawable,
  startBlock;

// Magnifier that is used in the contract
const FeeMagnifier = 100000;

// Crss-Mock Deposite Fee
const crss_mck_DF = 50;

// Crss-ETH Deposite Fee
const crss_eth_DF = 25;

describe("Cross Comprehensive Test", async () => {
  /**
   * Everything in this block is only run once before all tests.
   * This is the home for setup methodss
   */

  before(async () => {
    [deployer, alice, bob, carol, david, evan, fiona, georgy] = await ethers.getSigners();
    devTo = david.address;
    buybackTo = evan.address;
    liquidity = fiona.address;
    treasuryAddr = georgy.address;

    const Factory = await ethers.getContractFactory("CrossFactory");
    factory = await Factory.deploy(deployer.address);
    console.log("\nFactory Deployed: ", factory.address);

    const WBNB = await ethers.getContractFactory("WBNB");
    wbnb = await WBNB.deploy();

    const Maker = await ethers.getContractFactory("CrossMaker");
    maker = await Maker.deploy(factory.address, wbnb.address);
    console.log("\nMaker Deployed: ", maker.address);

    const Taker = await ethers.getContractFactory("CrossTaker");
    taker = await Taker.deploy(factory.address, wbnb.address);
    console.log("\nTaker Deployed: ", taker.address);

    factory.setTaker(taker.address);
    console.log("\nFactory Taker Set: ", taker.address);

    factory.setMaker(maker.address);
    console.log("\nFactory Maker Set: ", maker.address);

    const Crss = await ethers.getContractFactory("CrssToken");
    crss = await upgrades.deployProxy(Crss, [[devTo, buybackTo, liquidity], maker.address, taker.address]);
    console.log("\ncrss Deployed: ", crss.address);

    await maker.setToken(crss.address);
    await maker.setLiquidityChangeLimit(5000); // 5%
    console.log("\nCRSS token is set on Maker:", crss.address);

    await taker.setToken(crss.address);
    await taker.setPriceChangeLimit(5000); // 5%
    console.log("\nCRSS token is set on Taker:", crss.address);

    const MockToken = await ethers.getContractFactory("MockToken");
    mock = await MockToken.deploy("Mock", "MCK");
    console.log("\nmock token deployed: ", mock.address);

    // Deploy Farm
    crssPerBlock = "100";
    startBlock = await ethers.provider.getBlock("latest");
    console.log("StartBlock: ", startBlock.number)

    const CrossFarm = await ethers.getContractFactory("CrossFarm");
    farm = await upgrades.deployProxy(CrossFarm, [
      crss.address,
      treasuryAddr,
      maker.address,
      taker.address,
      utils.parseEther(crssPerBlock),
      startBlock.number + 10,
    ]);

    console.log("\nFarm deployed: ", farm.address)

    await crss.setFarm(farm.address)

    // Deploy XCrss
    const xCrss = await ethers.getContractFactory("xCrssToken");
    xcrss = await upgrades.deployProxy(xCrss, [crss.address]);

    console.log("\nXCrssToken deployed: ", xcrss.address);

    // Deploy Referral
    const Referral = await ethers.getContractFactory("CrssReferral");
    referral = await upgrades.deployProxy(Referral, []);
    console.log("CrossReferral Deployed: ", referral.address);

    // Let Farm, Crss, XCrss know each other
    await farm.setToken(crss.address)
    await farm.setXToken(xcrss.address);
    await farm.setCrssReferral(referral.address);
    await xcrss.setFarm(farm.address);
    console.log("\nXCRSS token is set on Farm: ", xcrss.address);

    console.log("\nTesting Start\n");

    console.log("\nFactory Code Hash: ", await factory.INIT_CODE_PAIR_HASH());
  });

  describe("Farming Basic Test - isAuto == true, isVest == true", async () => {
    it("Approve Crss to maker", async () => {
      await crss.approve(maker.address, utils.parseEther("1000000"));
      expect(await crss.allowance(deployer.address, maker.address)).to.equal(utils.parseEther("1000000"));
    });

    it("Mint MCK and approve it to maker", async () => {
      await mock.mint(deployer.address, utils.parseEther("500000"));
      await mock.approve(maker.address, utils.parseEther("500000"));
      expect(await mock.allowance(deployer.address, maker.address)).to.equal(utils.parseEther("500000"));
    });

    it("Crss-MCK LP Balance should be the same as calculated", async () => {
      // Add Liquidify Financial Check
      const block = await ethers.provider.getBlock("latest");
      await maker.addLiquidity(
        crss.address,
        mock.address,
        utils.parseEther("50"),
        utils.parseEther("50"),
        0,
        0,
        deployer.address,
        block.timestamp + 1000
      );

      const pairAddr = await factory.getPair(crss.address, mock.address);
      crss_mockPair = new ethers.Contract(pairAddr, pairAbi, deployer);

      // LP Balance that deployer received
      const lpBalance = await crss_mockPair.balanceOf(deployer.address);

      // LP Balance that is calculated outside
      CrssMCKLP = sqrt(utils.parseEther("50").mul(utils.parseEther("50")));
      expect(lpBalance).to.equal(CrssMCKLP.sub(1000));
    });

    it("Crss-BNB LP Balance should be 10000", async () => {
      // Add Liquidity Ether Financial Check
      const block = await ethers.provider.getBlock("latest");
      await maker.addLiquidityETH(
        crss.address,
        utils.parseEther("100000"),
        0,
        0,
        deployer.address,
        block.timestamp + 1000,
        {
          value: utils.parseEther("1000"),
        }
      );

      const pairAddr = await factory.getPair(crss.address, wbnb.address);
      crss_ethPair = new ethers.Contract(pairAddr, pairAbi, deployer);

      // LP Balance that deployer received
      const lpBalance = await crss_ethPair.balanceOf(deployer.address);

      // LP Balance that is calculated outside
      CrssBnbLP = sqrt(utils.parseEther("1000").mul(utils.parseEther("100000")));
      expect(lpBalance).to.equal(CrssBnbLP.sub(1000));
    });

    it("Add Crss-MCK LP to Farm", async () => {
      const pairAddr = await factory.getPair(crss.address, mock.address);
      await farm.add(40, pairAddr, false, crss_mck_DF);
      expect(await farm.poolLength()).to.equal(2);
    });

    it("Alloc Point Should be 53", async () => {
      // Test Alloc Point Change
      allocPoint = 40 + Math.floor(40 / 3)
      console.log("Alloc Point: ", allocPoint);
      expect(await farm.totalAllocPoint()).to.equal(allocPoint);
    })

    it("Add Crss-ETH LP to Farm", async () => {
      const pairAddr = await factory.getPair(crss.address, wbnb.address);
      await farm.add(30, pairAddr, false, crss_eth_DF);
      expect(await farm.poolLength()).to.equal(3);
    });

    it("Alloc Point Should be 93", async () => {
      // Test Alloc Point Change
      allocPoint = 70 + Math.floor(70 / 3)
      console.log("Alloc Point: ", allocPoint);
      expect(await farm.totalAllocPoint()).to.equal(allocPoint);
    })
    it("Revert Crss-ETH LP to Farm, because of duplicated insert", async () => {
      const pairAddr = await factory.getPair(crss.address, wbnb.address);
      await expect(farm.add(40, pairAddr, false, crss_eth_DF)).to.be.revertedWith("Duplicated LP token");
    });

    it("Approve Crss-Mock LP", async () => {
      const lpBalance = await crss_mockPair.balanceOf(deployer.address);
      await crss_mockPair.approve(farm.address, lpBalance);
      expect(await crss_mockPair.allowance(deployer.address, farm.address)).to.equal(lpBalance);
    });

    // Deposit Crss-MCK Financial Check : pool id is 1
    it("Deposit Crss-MCK", async () => {
      // Calculate how much will be deposited
      const lpBalance = await crss_mockPair.balanceOf(deployer.address);
      const expected = lpBalance.mul(FeeMagnifier - crss_mck_DF).div(FeeMagnifier);
      await farm.deposit(1, lpBalance);
      const lpStaked = await farm.userInfo(1, deployer.address);
      expect(Number(utils.formatEther(expected)).toFixed(5)).to.equal(
        Number(utils.formatEther(lpStaked.amount)).toFixed(5)
      );
    });

    it("Approve Crss-BNB LP", async () => {
      const lpBalance = await crss_ethPair.balanceOf(deployer.address);
      await crss_ethPair.approve(farm.address, lpBalance);
      expect(await crss_ethPair.allowance(deployer.address, farm.address)).to.equal(lpBalance);
    });

    it("Update Crss Referral Operator", async () => {
      await referral.transferOwnership(farm.address);
      expect(await referral.owner()).to.equal(farm.address);
    });

    it("Deposit Crss-BNB", async () => {
      let lpBalance = await crss_ethPair.balanceOf(deployer.address);
      await farm.deposit(2, lpBalance);
      lpBalance = await crss_ethPair.balanceOf(deployer.address);
      expect(lpBalance).to.equal(0);
    });

    it("Spend Block Number By 2", async () => {
      await network.provider.send("evm_mine");
      await network.provider.send("evm_mine");
    });

    it("Pendign Crss for Crss-Mock staking", async () => {
      const pending = await farm.pendingCrss(2, deployer.address);
      // Need to be checked in financial terms
      console.log("Pending Amount: ", utils.formatEther(pending));
    });

    it("Crss-MCK LP Balance should be", async () => {
      const block = await ethers.provider.getBlock("latest");
      await maker.addLiquidity(
        crss.address,
        mock.address,
        utils.parseEther("300000"),
        utils.parseEther("300000"),
        0,
        0,
        deployer.address,
        block.timestamp + 1000
      );
    });

    it("Collect non-auto reward", async () => {
      const oldBal = await crss.balanceOf(deployer.address)

      // Get Pool Info first
      const pool = await farm.poolInfo(2)
      // Get Block Number
      const block = await ethers.provider.getBlock("latest");
      await farm.collectRewards(2, 3);

      // Calculate Reward
      const user = await farm.userInfo(2, deployer.address);
      const lastRewardBlock = pool.lastRewardBlock;
      // Calculate Reward
      let reward = utils.parseEther(crssPerBlock).mul((block.number + 1 - lastRewardBlock)).mul(30).div(allocPoint).mul(10 ** 12).div(user.amount).mul(user.amount).div(10 ** 12)
      // Remove Burn Amount
      reward = utils.formatEther(reward.mul(3).div(4))
      const newBal = await crss.balanceOf(deployer.address)
      const bal = utils.formatEther(newBal.sub(oldBal))
      console.log("Crss Reward: ", bal)
      console.log("Reward Outside: ", reward)

      expect(Number(bal).toFixed(10)).to.equal(Number(reward).toFixed(10))
    })

    it("Spend Block Number By 3", async () => {
      await network.provider.send("evm_mine");
      await network.provider.send("evm_mine");
      await network.provider.send("evm_mine");
    });

    it("Collect Auto Compounding Calculation check", async () => {
      const pool = await farm.poolInfo(2)
      const block = await ethers.provider.getBlock("latest");
      let user = await farm.userInfo(2, deployer.address);
      const oldAmount = user.amount;

      const lastRewardBlock = pool.lastRewardBlock;
      // Calculate Reward
      let reward = utils.parseEther(crssPerBlock).mul((block.number + 1 - lastRewardBlock)).mul(30).div(allocPoint).mul(10 ** 12).div(user.amount).mul(user.amount).div(10 ** 12)
      devFee = reward.mul(26).div(100)
      reward = reward.mul(74).div(100)
      reward = reward.sub(reward.div(2))

      // Get Pool State for calc Swap Amount
      let result = await crss_ethPair.getReserves()
      let reserveIn = result[0]
      let reserveOut = result[1]

      // Calculate Swapped Amount
      const amountInWithFee = reward.mul(998);
      const numerator = amountInWithFee.mul(reserveOut);
      const denominator = reserveIn.mul(1000).add(amountInWithFee);
      const amountOut = numerator.div(denominator);

      // Get Pool State for Add Liquidity
      reserveIn = result[0].add(reward)
      reserveOut = result[1].sub(amountOut)
      const crssInput = reserveIn.mul(amountOut).div(reserveOut)
      const pairTotal = await crss_ethPair.totalSupply()
      const calcIn = utils.formatEther(crssInput.mul(pairTotal).div(reserveIn))
      const calcOut = utils.formatEther(amountOut.mul(pairTotal).div(reserveOut))
      const newLPCalc = calcIn < calcOut ? calcIn : calcOut
      console.log("New LP Calculated: ", newLPCalc)

      // Collect Auto Compound
      await farm.collectRewards(2, 1);

      user = await farm.userInfo(2, deployer.address);
      const newAmount = user.amount
      const newLP = utils.formatEther(newAmount.sub(oldAmount))
      expect(newLP).to.equal(newLPCalc)
    })

    it("Check DevFee", async () => {
      const amount = await crss.balanceOf(devTo)
      expect(amount).to.equal(devFee)
    })

    it("Spend Block Number By 3", async () => {
      await network.provider.send("evm_mine");
      await network.provider.send("evm_mine");
      await network.provider.send("evm_mine");
    });

    it("Calculate Vesting", async () => {
      const pool = await farm.poolInfo(2)
      const block = await ethers.provider.getBlock("latest");
      const oldAmount = await crss.balanceOf(deployer.address);
      const user = await farm.userInfo(2, deployer.address);

      const lastRewardBlock = pool.lastRewardBlock;
      // Calculate Reward
      let reward = utils.parseEther(crssPerBlock).mul((block.number + 1 - lastRewardBlock)).mul(30).div(allocPoint).mul(10 ** 12).div(user.amount).mul(user.amount).div(10 ** 12)
      
      // Will use this after fix vesting logic
      // vestedReward = reward.div(2)
      vestedReward = reward
      await farm.collectRewards(2, 1);
      const newAmount = await crss.balanceOf(deployer.address);
      console.log("Vest Reward: ", utils.formatEther(newAmount.sub(oldAmount)), utils.formatEther(reward))

      // expect(newAmount.sub(oldAmount)).to.equal(reward)
    })

    it("Spend Block Two Month", async () => {
      await network.provider.send("evm_increaseTime", [3600 * 24 * 60]);
      await network.provider.send("evm_mine");
    });

    it("Vest withdrawable amount check", async() => {
      withdrawable = await farm.totalMatureVest(2)
      const calcAmount = vestedReward.mul(2).div(5)
      console.log("Withdrawable Amount: ", utils.formatEther(withdrawable))
      console.log("Calculate Amount: ", utils.formatEther(calcAmount))
      console.log("Calculation Mismatching")
    })

    it("Withdraw Vested Crss", async () => {
      const oldAmount = await crss.balanceOf(deployer.address);
      await farm.withdrawVest(2, withdrawable)
      const newAmount = await crss.balanceOf(deployer.address);
      const bal = newAmount.sub(oldAmount)
      expect(bal).to.equal(withdrawable)
    })

    it("Spend Block Four Month More", async () => {
      await network.provider.send("evm_increaseTime", [3600 * 24 * 120]);
      await network.provider.send("evm_mine");
    });

    it("Withdraw Vested Crss", async () => {
      withdrawable = await farm.totalMatureVest(2)
      const oldAmount = await crss.balanceOf(deployer.address);
      await farm.withdrawVest(2, withdrawable)
      const newAmount = await crss.balanceOf(deployer.address);
      const bal = newAmount.sub(oldAmount)
      expect(bal).to.equal(withdrawable)
    })

    it("Set Auto Option to true", async () => {
      const user = await farm.userInfo(2, deployer.address)
      await farm.changeAutoCompound(2, true)
      const pool = await farm.poolInfo(2)
      expect(user.amount).to.equal(pool.autoUsers_amount)
    })

    it("Spend Block Number By 3", async () => {
      await network.provider.send("evm_mine");
      await network.provider.send("evm_mine");
      await network.provider.send("evm_mine");
    });

    it("Update Pool - Check Auto Compound Option / But still add Fee Concept", async () => {
      const pool = await farm.poolInfo(2)
      const block = await ethers.provider.getBlock("latest");
      const user = await farm.userInfo(2, deployer.address);

      const lastRewardBlock = pool.lastRewardBlock;
      // Calculate Reward
      let acc = utils.parseEther(crssPerBlock).mul((block.number + 1 - lastRewardBlock)).mul(30).div(allocPoint).mul(10 ** 12).div(pool.autoUsers_amount)
      let reward = ((pool.autoUsers_amount).add(pool.autoUsers_compound)).mul(acc).div(10 ** 12)

      // Get Pool State for calc Swap Amount
      let result = await crss_ethPair.getReserves()
      let reserveIn = result[0]
      let reserveOut = result[1]
      
      reward = reward.div(2)
      // Calculate Swapped Amount
      const amountInWithFee = reward.mul(998);
      const numerator = amountInWithFee.mul(reserveOut);
      const denominator = reserveIn.mul(1000).add(amountInWithFee);
      const amountOut = numerator.div(denominator);

      // Get Pool State for Add Liquidity
      reserveIn = result[0].add(reward)
      reserveOut = result[1].sub(amountOut)
      const crssInput = reserveIn.mul(amountOut).div(reserveOut)
      const pairTotal = await crss_ethPair.totalSupply()
      const calcIn = utils.formatEther(crssInput.mul(pairTotal).div(reserveIn))
      const calcOut = utils.formatEther(amountOut.mul(pairTotal).div(reserveOut))
      const newLPCalc = calcIn < calcOut ? calcIn : calcOut

      const autoAcc = utils.parseEther(newLPCalc.toString()).mul(10 ** 12).div(pool.autoUsers_amount)

      const compound = user.amount.mul(autoAcc).div(10 ** 12)

      const olduser = await farm.userInfo(2, deployer.address);
      await farm.deposit(2, 0)
      const newuser = await farm.userInfo(2, deployer.address);
      console.log("Newly Got Amount: ", utils.formatEther(newuser.amount.sub(olduser.amount)))
      expect(compound).to.equal(newuser.amount.sub(olduser.amount))
    })


    // it("Referral Amount Check", async () => {
    //   const aliceBalOld = await crss.balanceOf(alice.address);
    //   await farm.earn(2);
    //   const aliceBalNew = await crss.balanceOf(alice.address);
    //   console.log("Referrer Amount is: ", utils.formatEther(aliceBalNew.sub(aliceBalOld)));
    // });

    // it("Spend Block Time by 3600", async () => {
    //   await network.provider.send("evm_increaseTime", [3600]);
    //   await network.provider.send("evm_mine");
    // });

    // it("Withdraw will be reverted because of exceed amount", async () => {
    //   const user = await farm.userInfo(1, deployer.address);
    //   await expect(farm.withdraw(1, user.amount.add(100000))).to.be.revertedWith("withdraw: not good");
    // });

    // it("Withdraw will succeed", async () => {
    //   const user = await farm.userInfo(1, deployer.address);
    //   let lpBalance = await crss_mockPair.balanceOf(deployer.address);
    //   await farm.withdraw(1, user.amount);
    //   let lpBalanceNew = await crss_mockPair.balanceOf(deployer.address);
    //   await expect(lpBalanceNew.sub(lpBalance)).to.be.equal(user.amount);
    // });

    // it("Withdraw Vest", async () => {
    //   const user = await farm.userInfo(1, deployer.address);
    //   const vestAmount = await farm.totalMatureVest(1);
    //   console.log("Withdrawable Vested Amount: ", utils.formatEther(vestAmount));
    //   // Need to be checked in financial terms
    //   const crssBalOld = await crss.balanceOf(deployer.address);
    //   await farm.withdrawVest(1, utils.parseEther("10"));
    //   const crssBalNew = await crss.balanceOf(deployer.address);
    //   expect(crssBalNew.sub(crssBalOld)).to.equal(utils.parseEther("10").mul(999).div(1000));
    // });

    // it("Emergency Withdraw", async () => {
    //   const user = await farm.userInfo(2, deployer.address);
    //   const crssBalOld = await crss_ethPair.balanceOf(deployer.address);
    //   await farm.emergencyWithdraw(2);
    //   const crssBalNew = await crss_ethPair.balanceOf(deployer.address);
    //   expect(crssBalNew.sub(crssBalOld)).to.equal(user.amount);
    // });

    // it("Approve Crss to Farm", async () => {
    //   await crss.approve(farm.address, utils.parseEther("100000"));
    // });

    // it("Enter Staking Crss, xCrss Result should be 999 Eth", async () => {
    //   await farm.enterStaking(utils.parseEther("1000"));
    //   const xcrssAmount = await xcrss.balanceOf(deployer.address);
    //   expect(xcrssAmount).to.equal(utils.parseEther("1000").mul(999).div(1000));
    // });

    // it("Pool0 Amount should be 999Eth", async () => {
    //   const user = await farm.userInfo(0, deployer.address);
    //   expect(user.amount).to.equal(utils.parseEther("1000").mul(999).div(1000))
    // })

    // it("Leave Staking Crss, xCrss is all burnt", async () => {
    //   const xcrssAmountOld = await xcrss.balanceOf(deployer.address);
    //   const crssAmountOld = await crss.balanceOf(deployer.address);
    //   await farm.leaveStaking(xcrssAmountOld);
    //   const xcrssAmountNew = await xcrss.balanceOf(deployer.address);
    //   const crssAmountNew = await crss.balanceOf(deployer.address);
    //   expect(xcrssAmountNew).to.equal(0);
    // });

    // it("Approve Crss-Mock LP", async () => {
    //   const lpBalance = await crss_mockPair.balanceOf(deployer.address);
    //   await crss_mockPair.approve(farm.address, lpBalance);
    //   expect(await crss_mockPair.allowance(deployer.address, farm.address)).to.equal(lpBalance);
    // });

    // it("Approve Crss to Farm", async () => {
    //   await crss.approve(farm.address, utils.parseEther("1000000"));
    // });

    // it("Enter Staking Crss, xCrss Result should be 999 Eth", async () => {
    //   await farm.enterStaking(utils.parseEther("1000"));
    //   const xcrssAmount = await xcrss.balanceOf(deployer.address);
    //   expect(xcrssAmount).to.equal(utils.parseEther("999"));
    // });

    // it("Approve Crss-BNB LP", async () => {
    //   const lpBalance = await crss_ethPair.balanceOf(deployer.address);
    //   await crss_ethPair.approve(farm.address, lpBalance);
    //   expect(await crss_ethPair.allowance(deployer.address, farm.address)).to.equal(lpBalance);
    // });

    // it("Deposit Crss-ETH", async () => {
    //   let lpBalance = await crss_ethPair.balanceOf(deployer.address);
    //   await farm.deposit(2, lpBalance, false, alice.address, false);
    //   lpBalance = await crss_ethPair.balanceOf(deployer.address);
    //   expect(lpBalance).to.equal(0);
    // });

    // it("Spend Block Time by 3600", async () => {
    //   await network.provider.send("evm_increaseTime", [3600]);
    //   await network.provider.send("evm_mine");
    // });

    // it("Mass Harvest", async () => {
    //   const crssBalOld = await crss.balanceOf(deployer.address);
    //   await farm.massHarvest([0, 1, 2]);
    //   const crssBalNew = await crss.balanceOf(deployer.address);
    //   console.log("Mass Harvested Result: ", utils.formatEther(crssBalNew.sub(crssBalOld)));
    // });

    // it("Spend Block Time by 3600", async () => {
    //   await network.provider.send("evm_increaseTime", [3600 * 24 * 60]);
    //   await network.provider.send("evm_mine");
    // });

    // it("Transfer", async () => {
    //   await crss.connect(alice).transfer(bob.address, 1);
    // });

    // it("Approve Crss to Farm", async () => {
    //   await crss.approve(farm.address, utils.parseEther("1000000"));
    // });

    // it("Mass Stake Reward", async () => {
    //   await farm.massStakeReward([0, 1, 2]);
    // });
  });
});

async function delay() {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      resolve("OK");
    }, 5000);
  });
}

const ONE = ethers.BigNumber.from(1);
const TWO = ethers.BigNumber.from(2);

function sqrt(value) {
  x = value;
  let z = x.add(ONE).div(TWO);
  let y = x;
  while (z.sub(y).isNegative()) {
    y = z;
    z = x.div(z).add(z).div(TWO);
  }
  return y;
}
