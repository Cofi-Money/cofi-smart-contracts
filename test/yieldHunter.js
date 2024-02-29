/* global ethers */

const { ethers } = require('hardhat');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const MAX_UINT =
  '115792089237316195423570985008687907853269984665640564039457584007913129639935';

describe('Test yield hunter', function () {
  async function deploy() {
    const accounts = await ethers.getSigners();
    const owner = accounts[0];

    // Deploy ERC20 contracts with varying decimals.
    // Mints 1,000 tokens to owner upon deployment.
    const USDC = await ethers.getContractFactory('ERC20Token');
    const usdc = await USDC.deploy('USDC', 'USDC', 6);
    await usdc.waitForDeployment();
    console.log('USDC deployed: ', await usdc.getAddress());

    const USDT = await ethers.getContractFactory('ERC20Token');
    const usdt = await USDT.deploy('USDT', 'USDT', 8);
    await usdt.waitForDeployment();
    console.log('USDT deployed: ', await usdt.getAddress());

    const DAI = await ethers.getContractFactory('ERC20Token');
    const dai = await DAI.deploy('Dai', 'DAI', 18);
    await dai.waitForDeployment();
    console.log('Dai deployed: ', await dai.getAddress());

    // Deploy Vault contracts
    const VUSDC = await ethers.getContractFactory('Vault');
    const vusdc = await VUSDC.deploy('VUSDC', 'vUSDC', await usdc.getAddress());
    await vusdc.waitForDeployment();
    console.log('vUSDC deployed: ', await vusdc.getAddress());

    const VUSDT = await ethers.getContractFactory('Vault');
    const vusdt = await VUSDT.deploy('VUSDT', 'vUSDT', await usdt.getAddress());
    await vusdt.waitForDeployment();
    console.log('vUSDT deployed: ', await vusdt.getAddress());

    const VDAI = await ethers.getContractFactory('Vault');
    const vdai = await VDAI.deploy('VDAI', 'vDAI', await dai.getAddress());
    await vdai.waitForDeployment();
    console.log('vDAI deployed: ', await vdai.getAddress());

    // Approve Vault spends
    await usdc.approve(await vusdc.getAddress(), MAX_UINT);
    await usdt.approve(await vusdt.getAddress(), MAX_UINT);
    await dai.approve(await vdai.getAddress(), MAX_UINT);
    console.log('Approved vault spends');

    // Do Vault deposits
    await vusdc.deposit(
      await usdc.balanceOf(await owner.getAddress()),
      await owner.getAddress()
    );
    await vusdt.deposit(
      await usdt.balanceOf(await owner.getAddress()),
      await owner.getAddress()
    );
    await vdai.deposit(
      await dai.balanceOf(await owner.getAddress()),
      await owner.getAddress()
    );
    console.log('Executed vault deposits');

    // Deploy YieldHunter.sol
    const YieldHunter = await ethers.getContractFactory('YieldHunter');
    // Use dummy address.
    const yieldHunter = await YieldHunter.deploy(await usdc.getAddress());
    await yieldHunter.waitForDeployment();
    console.log('Yield Hunter deployed: ', await yieldHunter.getAddress());

    // Add Vault info
    await yieldHunter.addVault(
      // Use dummy address.
      await usdc.getAddress(),
      await vusdc.getAddress(),
      6,
      1
    );
    await yieldHunter.addVault(
      // Use dummy address.
      await usdc.getAddress(),
      await vusdt.getAddress(),
      8,
      1
    );
    await yieldHunter.addVault(
      // Use dummy address.
      await usdc.getAddress(),
      await vdai.getAddress(),
      18,
      1
    );

    // Do initial capture
    await yieldHunter.capture(await usdc.getAddress());

    return { yieldHunter, usdc, vusdc, usdt, vusdt, dai, vdai };
  }

  it('Should return correct target for strategy', async function () {
    const { yieldHunter, usdc, vusdc, usdt, vusdt, dai, vdai } =
      await loadFixture(deploy);

    /**
     * Simulate yield with even #entries
     *
     * vUSDC => [+1, +3, +3, +9, +1, +3]
     * - Mean: 3.33
     * - Median: 3
     * vUSDT => [+1, +1, +3, +20, +1, +2]
     * - Mean: 4.66
     * - Median: 1.5
     * vDAI => [+2, +2, +2, +10, +3, +3]
     * - Mean: 3.66
     * - Median: 2.5
     */
    // T1
    await usdc.mint(await vusdc.getAddress(), 10);
    await usdt.mint(await vusdt.getAddress(), 10);
    await dai.mint(await vdai.getAddress(), 20);
    await yieldHunter.capture(await usdc.getAddress());
    // T2
    await usdc.mint(await vusdc.getAddress(), 30);
    await usdt.mint(await vusdt.getAddress(), 10);
    await dai.mint(await vdai.getAddress(), 20);
    await yieldHunter.capture(await usdc.getAddress());
    // T3
    await usdc.mint(await vusdc.getAddress(), 30);
    await usdt.mint(await vusdt.getAddress(), 30);
    await dai.mint(await vdai.getAddress(), 20);
    await yieldHunter.capture(await usdc.getAddress());
    // T4
    await usdc.mint(await vusdc.getAddress(), 90);
    await usdt.mint(await vusdt.getAddress(), 200);
    await dai.mint(await vdai.getAddress(), 100);
    await yieldHunter.capture(await usdc.getAddress());
    // T5
    await usdc.mint(await vusdc.getAddress(), 10);
    await usdt.mint(await vusdt.getAddress(), 10);
    await dai.mint(await vdai.getAddress(), 30);
    await yieldHunter.capture(await usdc.getAddress());
    // T6
    await usdc.mint(await vusdc.getAddress(), 30);
    await usdt.mint(await vusdt.getAddress(), 20);
    await dai.mint(await vdai.getAddress(), 30);
    await yieldHunter.capture(await usdc.getAddress());
    // T7
    await usdc.mint(await vusdc.getAddress(), 10);
    await usdt.mint(await vusdt.getAddress(), 10);
    await dai.mint(await vdai.getAddress(), 10);
    await yieldHunter.capture(await usdc.getAddress());

    // console.log('Mean winner: ');
    // // Evaluates each vault for cofi token and returns highest.
    // console.log(await yieldHunter.evaluateMean(await usdc.getAddress(), 6, false));
    console.log('Median winner: ');
    console.log(
      await yieldHunter.evaluateMedian(await usdc.getAddress(), 7, false)
    );
  });
});
