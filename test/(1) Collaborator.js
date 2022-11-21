const {expect} = require('chai');
const {ethers} = require('hardhat');

describe('Token Contract', async () => {

    async function mineNBlocks(n) {
        await hre.network.provider.send("hardhat_mine", ["0x"+n.toString(16)]);
    }


    let collaborator;
    let [owner, user1, user2, user3] = [];
    
    beforeEach(async () => {
        [owner, user1, user2, user3] = await ethers.getSigners();
        const Collaborator = await ethers.getContractFactory('Collaborator');
        collaborator = await Collaborator.connect(owner).deploy();
        
    })

    describe("Minting", async() => {

        it('mints correctly', async () => {
            const val = 100;
            await collaborator.connect(user1).buyTokens({value: val});
            const balance = await collaborator.balanceOf(user1.address);
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            expect(balance).to.equal(initalMultiplier.mul(val));
        });

    })



    describe('Finalization', async () => {
        
        it("does not finalize early", async() => {
           const ICOLength = parseInt(await collaborator.ICOLength());

           await expect(collaborator.finalizeICO()).to.be.revertedWith("ICO period not passed");
           await mineNBlocks(ICOLength - 3);
           await expect(collaborator.finalizeICO()).to.be.revertedWith("ICO period not passed");
        });

        it("does finalize", async() => {
            const ICOLength = parseInt(await collaborator.ICOLength());
            const changeTime = parseInt(await collaborator.changeTime());
            await mineNBlocks(
                changeTime>ICOLength
                ?
                changeTime
                :
                ICOLength
                );
            await collaborator.setTargetAddress(user2.address);
            await expect(collaborator.sendTokens()).to.be.reverted;
            await collaborator.finalizeICO();
            await collaborator.sendTokens();
        })

        it("does not double finalize", async() => {
            const ICOLength = parseInt(await collaborator.ICOLength());
            await mineNBlocks(ICOLength);
            await collaborator.finalizeICO();
            await expect(collaborator.finalizeICO()).to.be.revertedWith("ICO already finalized");
        })

    });

    describe("Exchange", async() => {
        
        it("exchanges correctly", async() => {
            await collaborator.connect(user1).buyTokens({value: 100});
            let balance = await collaborator.balanceOf(user1.address);
            await collaborator.connect(user1).exchangeTokens(balance.div(2));
            await expect(await collaborator.balanceOf(user1.address)).to.equal(balance.div(2));
        })

        it("mint rate slows", async() => {
            const val = 80000000
            await collaborator.connect(user1).buyTokens({value: val});
            let balance = await collaborator.balanceOf(user1.address);
            const ICOLength = parseInt(await collaborator.ICOLength());
            await mineNBlocks(ICOLength);
            await expect(collaborator.finalizeICO());
            const mintRate = await collaborator.mintRate();
            await collaborator.connect(user1).exchangeTokens(balance.div(2));
            await expect(await collaborator.mintRate()).to.equal(mintRate.div(2));
        })

    });

    describe("Send Tokens", async() => {

        it("send tokens", async() => {
            const val = 80000000;
            await collaborator.connect(user1).buyTokens({value: val});
            let balance = await collaborator.balanceOf(user1.address);
            const ICOLength = parseInt(await collaborator.ICOLength());
            const changeTime = parseInt(await collaborator.changeTime())
            await mineNBlocks(ICOLength);
            await collaborator.finalizeICO();
            const mintRate = await collaborator.mintRate();
            await mineNBlocks(changeTime - ICOLength);
            await collaborator.setTargetAddress(user2.address);
            await collaborator.sendTokens();
            await expect(await collaborator.totalSupply()).to.be.closeTo(balance.add(mintRate.mul(changeTime - ICOLength)), mintRate.mul(10));
            await expect(await collaborator.balanceOf(user2.address)).to.be.closeTo(mintRate.mul(changeTime - ICOLength), mintRate.mul(10));
        })

    })

    describe("Ownership", async() => {

        it("owner is deployer", async() =>{
            const colabOwner = await collaborator.owner();
            expect(colabOwner).to.equal(owner.address);
        })

        it("transfer ownership once", async() => {
            await collaborator.connect(owner).transferOwnership(user1.address);
        })

        it("not transfer ownership twice", async() => {
            await collaborator.connect(owner).transferOwnership(user1.address);
            await expect(collaborator.connect(user1).transferOwnership(user2.address)).to.be.revertedWith("Ownership already set");
        })
    })

    describe("Settings", async() => {

        it("only owner can access settings", async() => {
            await expect(collaborator.connect(user1).setMintRate(0)).to.be.revertedWith("Ownable: caller is not the owner");
            await expect(collaborator.connect(user1).setMaxChange(0)).to.be.revertedWith("Ownable: caller is not the owner");
            await expect(collaborator.connect(user1).setChangeTime(0)).to.be.revertedWith("Ownable: caller is not the owner");
            await expect(collaborator.connect(user1).setTargetAddress(user1.address)).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("updates settings", async() => {
            await collaborator.connect(user1).buyTokens({value: 80000000});
            const ICOLength = parseInt(await collaborator.ICOLength());
            await mineNBlocks(ICOLength );
            await collaborator.finalizeICO();
            await mineNBlocks(ICOLength );

            const maxChange = await collaborator.maxChange();

            await collaborator.connect(owner).setMintRate(await collaborator.mintRate());
            await collaborator.connect(owner).setMaxChange(await collaborator.maxChange());
            await collaborator.connect(owner).setChangeTime(await collaborator.changeTime());
            await collaborator.connect(owner).setTargetAddress(await collaborator.targetAddress());
            
        });

        it("does not vary more than max allowed change (percentage)", async() => {
            await collaborator.connect(user1).buyTokens({value: 80000000});
            const ICOLength = parseInt(await collaborator.ICOLength());
            await mineNBlocks(ICOLength );
            await collaborator.finalizeICO();
            await mineNBlocks(ICOLength );

            const maxChange = (await collaborator.maxChange()).add("100000000000000000000")

            //maximum allowed change without reverting

            const maxChangedMintRate = (await collaborator.mintRate()).mul(maxChange).div("100000000000000000000");
            const maxChangedMaxChange = (await collaborator.maxChange()).mul(maxChange).div("100000000000000000000");
            const maxChangedChangeTime = (await collaborator.changeTime()).mul(maxChange).div("100000000000000000000");
            
            //under should fail

            await expect(collaborator.connect(owner).setMintRate(1)).to.be.revertedWith("Parameter change exceeds max allowed percent change");
            await expect(collaborator.connect(owner).setMaxChange(1)).to.be.revertedWith("Parameter change exceeds max allowed percent change");
            await expect(collaborator.connect(owner).setChangeTime(1)).to.be.revertedWith("Parameter change exceeds max allowed percent change");

            //one over should fail

            await expect(collaborator.connect(owner).setMintRate(maxChangedMintRate.add("1"))).to.be.revertedWith("Parameter change exceeds max allowed percent change");
            await expect(collaborator.connect(owner).setMaxChange(maxChangedMaxChange.add("1"))).to.be.revertedWith("Parameter change exceeds max allowed percent change");
            await expect(collaborator.connect(owner).setChangeTime(maxChangedChangeTime.add("1"))).to.be.revertedWith("Parameter change exceeds max allowed percent change");

            //one under should go through

            await collaborator.connect(owner).setMintRate(maxChangedMintRate.sub(1))
            await collaborator.connect(owner).setMaxChange(maxChangedMaxChange.sub(1))
            await collaborator.connect(owner).setChangeTime(maxChangedChangeTime.sub(1))
         });

        it("is time restricted", async() => {
            await collaborator.connect(user1).buyTokens({value: 80000000});
            const ICOLength = parseInt(await collaborator.ICOLength());
            await mineNBlocks(ICOLength );
            await collaborator.finalizeICO();
            await mineNBlocks(2 * ICOLength);

            const maxChange = (await collaborator.maxChange()).add("100000000000000000000")

            //maximum allowed change without reverting

            const maxChangedMintRate = (await collaborator.mintRate()).mul(maxChange).div("100000000000000000000");
            const maxChangedMaxChange = (await collaborator.maxChange()).mul(maxChange).div("100000000000000000000");
            const maxChangedChangeTime = (await collaborator.changeTime()).mul(maxChange).div("100000000000000000000");


            //should go through

            await collaborator.connect(owner).setMintRate(maxChangedMintRate.sub(1))
            await collaborator.connect(owner).setMaxChange(maxChangedMaxChange.sub(1))
            await collaborator.connect(owner).setChangeTime(maxChangedChangeTime.sub(1))

            await expect(collaborator.connect(owner).setMintRate(maxChangedMintRate.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
            await expect(collaborator.connect(owner).setMaxChange(maxChangedMaxChange.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
            await expect(collaborator.connect(owner).setChangeTime(maxChangedChangeTime.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");

            const changeTime = parseInt((await collaborator.changeTime()).toString())

            mineNBlocks(changeTime - 10);

            await expect(collaborator.connect(owner).setMintRate(maxChangedMintRate.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
            await expect(collaborator.connect(owner).setMaxChange(maxChangedMaxChange.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
            await expect(collaborator.connect(owner).setChangeTime(maxChangedChangeTime.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");

            mineNBlocks(5);

            await collaborator.connect(owner).setMintRate(maxChangedMintRate.sub(1))
            await collaborator.connect(owner).setMaxChange(maxChangedMaxChange.sub(1))
            await collaborator.connect(owner).setChangeTime(maxChangedChangeTime.sub(1))
        })
    });

});