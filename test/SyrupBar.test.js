const { advanceBlockTo } = require('@openzeppelin/test-helpers/src/time');
const { assert } = require('chai');
const PlantToken = artifacts.require('PlantToken');
const SyrupBar = artifacts.require('SyrupBar');

contract('SyrupBar', ([alice, bob, carol, dev, minter]) => {
  beforeEach(async () => {
    this.plant = await PlantToken.new({ from: minter });
    this.syrup = await SyrupBar.new(this.plant.address, { from: minter });
  });

  it('mint', async () => {
    await this.syrup.mint(alice, 1000, { from: minter });
    assert.equal((await this.syrup.balanceOf(alice)).toString(), '1000');
  });

  it('burn', async () => {
    await advanceBlockTo('650');
    await this.syrup.mint(alice, 1000, { from: minter });
    await this.syrup.mint(bob, 1000, { from: minter });
    assert.equal((await this.syrup.totalSupply()).toString(), '2000');
    await this.syrup.burn(alice, 200, { from: minter });

    assert.equal((await this.syrup.balanceOf(alice)).toString(), '800');
    assert.equal((await this.syrup.totalSupply()).toString(), '1800');
  });

  it('safePlantTransfer', async () => {
    assert.equal(
      (await this.plant.balanceOf(this.syrup.address)).toString(),
      '0'
    );
    await this.plant.mint(this.syrup.address, 1000, { from: minter });
    await this.syrup.safePlantTransfer(bob, 200, { from: minter });
    assert.equal((await this.plant.balanceOf(bob)).toString(), '200');
    assert.equal(
      (await this.plant.balanceOf(this.syrup.address)).toString(),
      '800'
    );
    await this.syrup.safePlantTransfer(bob, 2000, { from: minter });
    assert.equal((await this.plant.balanceOf(bob)).toString(), '1000');
  });
});
