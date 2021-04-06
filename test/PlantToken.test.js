const { assert } = require("chai");

const PlantToken = artifacts.require('PlantToken');

contract('PlantToken', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.plant = await PlantToken.new({ from: minter });
    });


    it('mint', async () => {
        await this.plant.mint(alice, 1000, { from: minter });
        assert.equal((await this.plant.balanceOf(alice)).toString(), '1000');
    })
});
