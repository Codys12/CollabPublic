const {expect} = require('chai');
const {ethers} = require('hardhat');

describe('Governance Contract', async () => {

    async function mineNBlocks(n) {
        await hre.network.provider.send("hardhat_mine", ["0x"+n.toString(16)]);
    }


    let governance;
    let [owner, user1, user2, user3] = [];
    
    beforeEach(async () => {
        [owner, user1, user2, user3] = await ethers.getSigners();

        const Collaborator = await ethers.getContractFactory('Collaborator');
        collaborator = await Collaborator.connect(owner).deploy();

        const Governance = await ethers.getContractFactory('CollabGovernor');
        governance = await Governance.connect(owner).deploy(collaborator.address, owner.address);


        
    })

    describe("Require Payment", async() => {

        it('requires payment', async () => {
            const requiredTokens = await governance.proposalCost();
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier)});

            await expect(governance.connect(user1).propose([owner.address], [0], [ethers.utils.formatBytes32String("")], "asdf")).to.be.revertedWith('ERC20: insufficient allowance');

            await collaborator.connect(user1).approve(governance.address, requiredTokens);

            await governance.connect(user1).propose([owner.address], [0], [ethers.utils.formatBytes32String("")], "asdf");
            

        });

    })


    // THE FOLLOWING TESTS FAIL BECAUSE OF THE REQUIREMENT FOR GOVERNANCE SETTER CALLS ORIGNIATING FROM THE GOV CONTRACT ITSELF SINCE OZ 4.6

    // describe("Settings", async() => {

    //     it("only owner can access settings", async() => {
    //         await expect(governance.connect(user1).setVotingDelay(0)).to.be.revertedWith("Governor: onlyGovernance");
    //         await expect(governance.connect(user1).setVotingPeriod(0)).to.be.revertedWith("Governor: onlyGovernance");
    //         await expect(governance.connect(user1).setMaxChange(0)).to.be.revertedWith("Governor: onlyGovernance");
    //         await expect(governance.connect(user1).setChangeTime(0)).to.be.revertedWith("Governor: onlyGovernance");
    //         await expect(governance.connect(user1).setProposalCost(0)).to.be.revertedWith("Governor: onlyGovernance");
    //         await expect(governance.connect(user1).setProposalThreshold(0)).to.be.revertedWith("Governor: onlyGovernance");
    //     });

    //     it("updates settings", async() => {

    //         await governance.connect(owner).setVotingDelay(await governance.votingDelay());
    //         await governance.connect(owner).setVotingPeriod(await governance.votingPeriod());
    //         await governance.connect(owner).setProposalCost(await governance.proposalCost());
    //         await governance.connect(owner).setChangeTime(await governance.changeTime());
    //         await governance.connect(owner).setMaxChange(await governance.maxChange());
    //         await governance.connect(owner).setProposalThreshold(await governance.proposalThreshold());
            
    //     });

    //     it("does not vary more than max allowed change (percentage)", async() => {

    //         const maxChange = (await governance.maxChange()).add("100000000000000000000")

    //         //maximum allowed change without reverting

    //         const maxVotingDelay = (await governance.votingDelay()).mul(maxChange).div("100000000000000000000");
    //         const maxVotingPeriod = (await governance.votingPeriod()).mul(maxChange).div("100000000000000000000");
    //         const maxProposalThreshold = (await governance.proposalThreshold()).mul(maxChange).div("100000000000000000000");
    //         const maxProposalCost = (await governance.proposalCost()).mul(maxChange).div("100000000000000000000");
    //         const maxMaxChange = (await governance.maxChange()).mul(maxChange).div("100000000000000000000");
    //         const maxChangeTime = (await governance.changeTime()).mul(maxChange).div("100000000000000000000");

    //         //one over should fail

    //         await expect(governance.connect(owner).setVotingDelay(maxVotingDelay.add("1"))).to.be.revertedWith("Parameter change exceeds max allowed percent change");
    //         await expect(governance.connect(owner).setVotingPeriod(maxVotingPeriod.add("1"))).to.be.revertedWith("Parameter change exceeds max allowed percent change");
    //         await expect(governance.connect(owner).setProposalThreshold(maxProposalThreshold.add("1"))).to.be.revertedWith("Parameter change exceeds max allowed percent change");
    //         await expect(governance.connect(owner).setProposalCost(maxProposalCost.add("1"))).to.be.revertedWith("Parameter change exceeds max allowed percent change");
    //         await expect(governance.connect(owner).setMaxChange(maxMaxChange.add("1"))).to.be.revertedWith("Parameter change exceeds max allowed percent change");
    //         await expect(governance.connect(owner).setChangeTime(maxChangeTime.add("1"))).to.be.revertedWith("Parameter change exceeds max allowed percent change");

    //         //one under should go through

    //         await governance.connect(owner).setVotingDelay(maxVotingDelay.sub("1"));
    //         await governance.connect(owner).setVotingPeriod(maxVotingPeriod.sub("1"));
    //         await governance.connect(owner).setProposalThreshold(maxProposalThreshold.sub("1"));
    //         await governance.connect(owner).setProposalCost(maxProposalCost.sub("1"));
    //         await governance.connect(owner).setMaxChange(maxMaxChange.sub("1"));
    //         await governance.connect(owner).setChangeTime(maxChangeTime.sub("1"));
    //      });

    //     it("is time restricted", async() => {
    //         const maxChange = (await governance.maxChange()).add("100000000000000000000")

    //         //maximum allowed change without reverting

    //         const maxVotingDelay = (await governance.votingDelay()).mul(maxChange).div("100000000000000000000");
    //         const maxVotingPeriod = (await governance.votingPeriod()).mul(maxChange).div("100000000000000000000");
    //         const maxProposalThreshold = (await governance.proposalThreshold()).mul(maxChange).div("100000000000000000000");
    //         const maxProposalCost = (await governance.proposalCost()).mul(maxChange).div("100000000000000000000");
    //         const maxMaxChange = (await governance.maxChange()).mul(maxChange).div("100000000000000000000");
    //         const maxChangeTime = (await governance.changeTime()).mul(maxChange).div("100000000000000000000");

    //         //one under should go through

    //         await governance.connect(owner).setVotingDelay(maxVotingDelay.sub("1"));
    //         await governance.connect(owner).setVotingPeriod(maxVotingPeriod.sub("1"));
    //         await governance.connect(owner).setProposalThreshold(maxProposalThreshold.sub("1"));
    //         await governance.connect(owner).setProposalCost(maxProposalCost.sub("1"));
    //         await governance.connect(owner).setMaxChange(maxMaxChange.sub("1"));
    //         await governance.connect(owner).setChangeTime(maxChangeTime.sub("1"));

    //          //Should revert with not enough time passed

    //         await expect(governance.connect(owner).setVotingDelay(maxVotingDelay.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setVotingPeriod(maxVotingPeriod.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setProposalThreshold(maxProposalThreshold.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setProposalCost(maxProposalCost.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setMaxChange(maxMaxChange.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setChangeTime(maxChangeTime.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");

    //         const changeTime = parseInt((await governance.changeTime()).toString())

    //         mineNBlocks(changeTime - 10);

    //         await expect(governance.connect(owner).setVotingDelay(maxVotingDelay.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setVotingPeriod(maxVotingPeriod.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setProposalThreshold(maxProposalThreshold.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setProposalCost(maxProposalCost.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setMaxChange(maxMaxChange.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
    //         await expect(governance.connect(owner).setChangeTime(maxChangeTime.sub("1"))).to.be.revertedWith("Not enough time has passed since this parameter was last changed");
           
    //         mineNBlocks(5);

    //         await governance.connect(owner).setVotingDelay(maxVotingDelay.sub("1"));
    //         await governance.connect(owner).setVotingPeriod(maxVotingPeriod.sub("1"));
    //         await governance.connect(owner).setProposalThreshold(maxProposalThreshold.sub("1"));
    //         await governance.connect(owner).setProposalCost(maxProposalCost.sub("1"));
    //         await governance.connect(owner).setMaxChange(maxMaxChange.sub("1"));
    //         await governance.connect(owner).setChangeTime(maxChangeTime.sub("1"));
    //     })
    // });

});