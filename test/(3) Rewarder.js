const {expect} = require('chai');
const {ethers} = require('hardhat');

describe('Governance Contract', async () => {

    async function mineNBlocks(n) {
        await hre.network.provider.send("hardhat_mine", ["0x"+n.toString(16)]);
    }


    let rewarder;
    let collaborator;
    let storage
    let [owner, user1, user2, user3] = [];
    
    beforeEach(async () => {
        [owner, user1, user2, user3] = await ethers.getSigners();

        const Collaborator = await ethers.getContractFactory('Collaborator');
        collaborator = await Collaborator.connect(owner).deploy();

        const Storage = await ethers.getContractFactory('Storage');
         storage = await Storage.connect(owner).deploy();

        const Rewarder = await ethers.getContractFactory('RewardContract');
        rewarder = await Rewarder.connect(owner).deploy(collaborator.address, storage.address, owner.address);

        
    });

    describe("Proposal", async() => {

        
        it('requires finalization', async () => {
            const requiredTokens = await rewarder.requiredCollateral();
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier)});
            await collaborator.connect(user1).approve(rewarder.address, requiredTokens);

            await expect(rewarder.connect(user1).propose([0], user1.address, "asdf")).to.be.revertedWith('ICO not yet finalized.');


        });

        it('requires payment', async () => {
            const requiredTokens = await rewarder.requiredCollateral();
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier)});
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);

            await collaborator.finalizeICO();

            await expect(rewarder.connect(user1).propose(0, user1.address, "asdf")).to.be.revertedWith('ERC20: insufficient allowance');

            await collaborator.connect(user1).approve(rewarder.address, requiredTokens);

            await rewarder.connect(user1).propose(0, user1.address, "asdf");
            

        });

        it('previous version must exist', async () => {
            const requiredTokens = await rewarder.requiredCollateral();
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier)});
            await collaborator.connect(user1).approve(rewarder.address, requiredTokens);
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);

            await collaborator.finalizeICO()

            await expect(rewarder.connect(user1).propose(1, user1.address, "asdf")).to.be.revertedWith('This project was not uploaded through an approved contract');
        })

        it('previous version must be accepted contract', async () => {
            const requiredTokens = await rewarder.requiredCollateral();
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier)});
            await collaborator.connect(user1).approve(rewarder.address, requiredTokens);
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);

            await collaborator.finalizeICO()
            
            await storage.uploadPost([0], 0, user1.address, "asdf", []);


            await expect(rewarder.connect(user1).propose(1, user1.address, "asdf")).to.be.revertedWith('This project was not uploaded through an approved contract');
        })

        it('uploads with previous version', async() => {
            const requiredTokens = (await rewarder.requiredCollateral()).mul(2);
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier)});
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);
            await collaborator.finalizeICO();
            await collaborator.connect(user1).approve(rewarder.address, requiredTokens);
            const tx = await rewarder.connect(user1).propose(0, user1.address, "asdf");
            const proposalId = (await tx.wait()).events[3].args.proposalId;
            await rewarder.connect(user1).propose(proposalId, user1.address, "asdf");
        })

    })

    describe("Voting", async() => {

        it('user can vote on new project', async() =>{
            const requiredTokens = (await rewarder.requiredCollateral());
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier).mul(2)});
            await collaborator.connect(user2).buyTokens({value: requiredTokens.div(initalMultiplier)});
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);
            await collaborator.finalizeICO();
            await collaborator.connect(user1).approve(rewarder.address, requiredTokens);
            const tx = await rewarder.connect(user1).propose(0, user1.address, "asdf");
            const proposalId = (await tx.wait()).events[3].args.proposalId;
            
            expect(await collaborator.balanceOf(user1.address)).to.equal(await collaborator.balanceOf(user2.address))

            await rewarder.connect(user1).castVote(proposalId, true, "good project");
            const votingPeriod = parseInt(await rewarder.votingPeriod());
            mineNBlocks(votingPeriod)
            await rewarder.connect(user2).castVote(proposalId, true, "good project");
        });

        it('user cannot double vote', async ()=>{
            const requiredTokens = (await rewarder.requiredCollateral());
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier).mul(2)});
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);
            await collaborator.finalizeICO();
            await collaborator.connect(user1).approve(rewarder.address, requiredTokens);
            const tx = await rewarder.connect(user1).propose(0, user1.address, "asdf");
            const proposalId = (await tx.wait()).events[3].args.proposalId;

            await rewarder.connect(user1).castVote(proposalId, true, "good project");
            await expect(rewarder.connect(user1).castVote(proposalId, true, "good project")).to.be.revertedWith("User has already voted");
        });


    });

    describe("rewarding", async() => {
        it("Does not reward early", async () =>{
            const requiredTokens = (await rewarder.requiredCollateral());
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier).mul(2)});
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);
            await collaborator.finalizeICO();
            await collaborator.connect(user1).approve(rewarder.address, requiredTokens);
            const tx = await rewarder.connect(user1).propose(0, user1.address, "asdf");
            const proposalId = (await tx.wait()).events[3].args.proposalId;

            await rewarder.connect(user1).castVote(proposalId, true, "good project");
            await expect(rewarder.connect(user1).rewardProposal(proposalId)).to.be.revertedWith("This proposal has not finished its voting phase");
        })

        it("rewards", async () =>{
            //REPLACE SETUP WITH HELPER FUNCTIONS LATER
            const requiredTokens = (await rewarder.requiredCollateral());
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier).mul(2)});
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);
            await collaborator.finalizeICO();
            const startBlock = parseInt((await hre.ethers.provider.getBlock("latest")).number);
            await collaborator.connect(user1).approve(rewarder.address, requiredTokens);
            const tx = await rewarder.connect(user1).propose(0, user1.address, "asdf");
            const proposalId = (await tx.wait()).events[3].args.proposalId;

            await rewarder.connect(user1).castVote(proposalId, true, "good project");

            const balance = await collaborator.balanceOf(user1.address);
            await collaborator.connect(user1).transfer(rewarder.address, balance);

            await collaborator.setTargetAddress(rewarder.address);

            const votingPeriod = parseInt(await rewarder.votingPeriod())

            mineNBlocks(votingPeriod + 1)

            const blockNumber = parseInt((await hre.ethers.provider.getBlock("latest")).number);
            const mintRate = await collaborator.mintRate();

            await rewarder.connect(user1).rewardProposal(proposalId);

            const newBalance = await collaborator.balanceOf(user1.address);

            await expect(newBalance).to.be.closeTo(balance.add(mintRate.mul(blockNumber - startBlock)), mintRate.mul(50))
        })

        it("splits reward", async () =>{
            //REPLACE SETUP WITH HELPER FUNCTIONS LATER
            const requiredTokens = await rewarder.requiredCollateral();
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier).mul(3)});
            await collaborator.connect(user2).buyTokens({value: requiredTokens.div(initalMultiplier).mul(3)});
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);
            await collaborator.finalizeICO();
            const startBlock = parseInt((await hre.ethers.provider.getBlock("latest")).number);

            await collaborator.connect(user1).approve(rewarder.address, requiredTokens.mul(2));

            let tx = await rewarder.connect(user1).propose(0, user1.address, "asdf");
            const proposalId = (await tx.wait()).events[3].args.proposalId;

            tx = await rewarder.connect(user1).propose(0, user1.address, "asdf");
            const proposal2Id = (await tx.wait()).events[3].args.proposalId;

            await rewarder.connect(user2).castVote(proposalId, true, "good project");
            await rewarder.connect(user2).castVote(proposal2Id, true, "good project");

            let balance = await collaborator.balanceOf(user1.address);
            await collaborator.connect(user1).transfer(rewarder.address, balance);

            await collaborator.setTargetAddress(rewarder.address);

            const votingPeriod = parseInt(await rewarder.votingPeriod())

            mineNBlocks(votingPeriod + 1)

            const blockNumber = parseInt((await hre.ethers.provider.getBlock("latest")).number);
            const mintRate = await collaborator.mintRate();
            const expectedReward = (await rewarder.eligibleRewards()).add(mintRate.mul(blockNumber - startBlock)).div(2);
            balance = await collaborator.balanceOf(user1.address);

            await rewarder.connect(user1).rewardProposal(proposalId);

            const newBalance = await collaborator.balanceOf(user1.address);

            await expect(newBalance).to.be.closeTo(balance.add(expectedReward).add(requiredTokens), mintRate)


        })

        it("reward propigates", async () =>{
            //REPLACE SETUP WITH HELPER FUNCTIONS LATER
            const requiredTokens = await rewarder.requiredCollateral();
            const initalMultiplier = await collaborator.INITIAL_COST_MULTIPLIER();
            await collaborator.connect(user1).buyTokens({value: requiredTokens.div(initalMultiplier).mul(3)});
            await collaborator.connect(user2).buyTokens({value: requiredTokens.div(initalMultiplier).mul(3)});
            await collaborator.connect(user3).buyTokens({value: requiredTokens.div(initalMultiplier).mul(3)});
            const ICOLength = await parseInt(await collaborator.ICOLength());
            mineNBlocks(ICOLength);
            await collaborator.finalizeICO();

            await collaborator.connect(user1).approve(rewarder.address, requiredTokens.mul(2));
            await collaborator.connect(user2).approve(rewarder.address, requiredTokens.mul(2));

            let tx = await rewarder.connect(user1).propose(0, user1.address, "asdf");
            const proposalId = (await tx.wait()).events[3].args.proposalId;


            await rewarder.connect(user3).castVote(proposalId, true, "good project");

            await collaborator.setTargetAddress(rewarder.address);

            const votingPeriod = parseInt(await rewarder.votingPeriod())

            mineNBlocks(votingPeriod + 1)

            await rewarder.connect(user1).rewardProposal(proposalId);


            tx = await rewarder.connect(user2).propose(proposalId, user2.address, "asdf");
            const proposal2Id = (await tx.wait()).events[3].args.proposalId;

            const startBlock = parseInt((await hre.ethers.provider.getBlock("latest")).number);

            await rewarder.connect(user3).castVote(proposal2Id, true, "good project");

            let balance = await collaborator.balanceOf(user2.address);
            await collaborator.connect(user2).transfer(rewarder.address, balance);

            mineNBlocks(votingPeriod + 1)

            const blockNumber = parseInt((await hre.ethers.provider.getBlock("latest")).number);
            const mintRate = await collaborator.mintRate();
            const expectedReward = (await rewarder.eligibleRewards()).add(mintRate.mul(blockNumber - startBlock)).div(2);
            balance = await collaborator.balanceOf(user2.address);

            await rewarder.connect(user2).rewardProposal(proposal2Id);

            const newBalance = await collaborator.balanceOf(user2.address);

            await expect(newBalance).to.be.closeTo(balance.add(expectedReward).add(requiredTokens), mintRate.mul(2))


        })
    });

    
});