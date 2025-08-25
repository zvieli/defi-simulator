import { expect } from "chai";
import { ethers } from "hardhat";

describe("YieldFarmSimulator & MockDAI integration", function () {
  let mockDai;
  let farm;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy MockDAI עם מחיר של 1 wei לטוקן
    const MockDAI = await ethers.getContractFactory("MockDAI");
    mockDai = await MockDAI.deploy(1);
    await mockDai.deployed();

    // Deploy YieldFarmSimulator עם APY של 10% ו־blocksPerYear = 1000
    const YieldFarmSimulator = await ethers.getContractFactory("YieldFarmSimulator");
    farm = await YieldFarmSimulator.deploy(
      await mockDai.getAddress(),
      10,
      1000
    );
    await farm.deployed();
  });

  it("user can buy MockDAI from faucet", async function () {
    await mockDai.connect(user1).faucet(500, { value: 500 });
    const bal = await mockDai.balanceOf(await user1.getAddress());
    expect(bal).to.equal(500);
  });

  it("deposit stores amount in farm", async function () {
    await mockDai.connect(user1).faucet(1000, { value: 1000 });
    await mockDai.connect(user1).approve(farm.address, 1000);
    await farm.connect(user1).deposit(1000);

    const dep = await farm.deposits(await user1.getAddress());
    expect(dep.amount).to.equal(1000);
    expect(dep.lastBlock).to.be.gt(0);
  });

  it("accrues yield after blocks", async function () {
    await mockDai.connect(user1).faucet(1000, { value: 1000 });
    await mockDai.connect(user1).approve(farm.address, 1000);
    await farm.connect(user1).deposit(1000);

    // Mine כמה בלוקים
    for (let i = 0; i < 5; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    const withYield = await farm.getBalance(await user1.getAddress());
    expect(withYield).to.be.gt(1000);
  });

  it("withdraw reduces deposit and transfers tokens", async function () {
    await mockDai.connect(user1).faucet(1000, { value: 1000 });
    await mockDai.connect(user1).approve(farm.address, 1000);
    await farm.connect(user1).deposit(1000);

    await ethers.provider.send("evm_mine", []);

    const before = await mockDai.balanceOf(await user1.getAddress());
    await farm.connect(user1).withdraw(400);
    const after = await mockDai.balanceOf(await user1.getAddress());

    expect(after).to.be.gt(before);
    const dep = await farm.deposits(await user1.getAddress());
    expect(dep.amount).to.be.lt(1000);
  });

  it("owner can change APY", async function () {
    await farm.connect(owner).setApy(20);
    expect(await farm.apy()).to.equal(20);
  });

  it("non-owner cannot change APY", async function () {
    await expect(farm.connect(user1).setApy(50)).to.be.reverted;
  });

  it("reverts on zero deposit", async function () {
    await expect(farm.connect(user1).deposit(0))
      .to.be.revertedWith("Amount must be greater than 0");
  });

  it("reverts on withdraw more than balance", async function () {
    await mockDai.connect(user1).faucet(100, { value: 100 });
    await mockDai.connect(user1).approve(farm.address, 100);
    await farm.connect(user1).deposit(100);
    await expect(farm.connect(user1).withdraw(200))
      .to.be.revertedWith("Insufficient balance");
  });

  it("calculates compound interest exactly as expected", async function () {
    const principal = 1000;
    const apy = await farm.apy();
    const blocksPerYear = await farm.blocksPerYear();

    await mockDai.connect(user1).faucet(principal, { value: principal });
    await mockDai.connect(user1).approve(farm.address, principal);
    await farm.connect(user1).deposit(principal);

    const blocksToMine = 10;
    for (let i = 0; i < blocksToMine; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    const ratePerBlock = Number(apy) / 100 / Number(blocksPerYear);
    let expected = principal;
    for (let i = 0; i < blocksToMine; i++) {
      expected = expected * (1 + ratePerBlock);
    }

    const onChain = Number(await farm.getBalance(await user1.getAddress()));
    const diff = Math.abs(onChain - expected);
    expect(diff).to.be.lessThan(0.000001 * expected);
  });
});
