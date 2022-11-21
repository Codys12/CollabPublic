// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IRewarder.sol";
import "./RewardSettings.sol";
import "../Storage.sol";
import "../ICollaborator.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";

contract RewardContract is ERC165, RewardSettings, IRewarder{
    
    using PRBMathUD60x18 for uint256;

    uint256 BLOCK_TIME = 12000; //12 second block time

    ERC20Votes _underlying;
    Storage _storageInstance;

    uint256 private _requiredCollateral;

    uint256 private totalActiveVotes;

    bool private _upgrading;
    bool private _upgradeFinalized;
    uint256 upgradeStartBlock;

    uint256 heldCollateral; //Collateral held by contract

    struct FlaggingData{
        address flagger;
        string reason;
        uint256 blockFlagged;
        
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voteAmount;

        uint256 totalVotes;

        uint256 approveVotes;
        uint256 disapproveVotes;

        uint256 incentivesDue;
    }

    struct ProjectProposal{
        ProposalState state;

        uint256 previousVersionIndex; //The index for the previous version of this project
        address rewardee; //The user that collects the reward from the project
        string IPFS_CID; //The content identifier of the project on IPFS

        uint256 blockCreated; //The block of creation of the project
        uint256 collateral; //The stake used to upload this project
        address proposer; //The user that covers collateral and uploads

        FlaggingData flaggingData;

        uint256 postIndex; //The index of the project in the storage instance

        mapping(address => bool) hasVoted;

        uint256 approveVotes;
        uint256 disapproveVotes;
    }

    mapping(address => uint256[]) incentives;

    mapping(uint256 => ProjectProposal) proposals;
    uint256 proposalIndex;

    constructor(address underlying, address storageInstance, address governor)
    RewardSettings(
        governor,  
        1000*60*60*24*1/BLOCK_TIME /* ~1 days */, 
        1000*60*60*24*3/BLOCK_TIME /* ~7 days */, 
        100e18 /* 100 tokens */, 
        20e18 /* ~20 percent */, 
        1000*60*60*24*7/BLOCK_TIME /* ~7 days */
    ){
        _underlying = ERC20Votes(underlying);
        _storageInstance = Storage(storageInstance);
    }


    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IRewarder).interfaceId || super.supportsInterface(interfaceId);
    }


    /**
     * @dev A check for whether a user is verified for quadratic voting
     */
    function isVerified(address user) public view override returns (bool){
        return false;
        /**
         * ADD VERIFICATION LOGIC 
        */
    }

    /**
     * @dev A check used for verifying the authority of project's contract versions
    */
    function acceptsContract(address version, uint256 blockNumber) public view override returns (bool) {
        return version == address(this);
    }

    function acceptedVersions() public view override returns (address[] memory){
        address[] memory returnVar = new address[](1);
        returnVar[0] = address(this);
        return returnVar;
    }

    /**
     * @notice module:core
     * @dev Current state of a proposal, following Compound's convention
     */
    function state(uint256 proposalId) public view override returns (ProposalState){
        return proposals[proposalId].state;
    }

    /**
     * @dev Returns the postIndex for given proposalId.
     */
    function postIndex(uint256 proposalId) public view override returns (uint256){
        return proposals[proposalId].postIndex;
    }

    function proposer(uint256 proposalId) public view override returns (address account){
        return proposals[proposalId].proposer;
    }

    /**
     * @dev Returns true if `account` has cast a vote on `proposalId`.
     */
    function hasVoted(uint256 proposalId, address account) public view override returns (bool){
        return proposals[proposalId].hasVoted[account];
    }

   /**
     * @dev Returns whether `account` has cast a vote on a flagged `proposalId`.
     */
    function hasVotedFlagged(uint256 proposalId, address account) public view override returns (bool){
        return proposals[proposalId].flaggingData.hasVoted[account];
    }
    

    // /**
    //  * @dev Delay, in number of blocks, between proposal upload and voting (unless flagged during this period)
    //  */
    // function flaggingDelay() public view override(IRewarder, RewardSettings) returns(uint256) {
    //     return super.flaggingDelay();
    // }

    /**
     * @dev Delay, in number of blocks, between project flagged and project voting begin (if proposal passed flagging)
     */
     function flaggingPeriod() public view override(IRewarder, RewardSettings) returns (uint256) {
         return super.flaggingPeriod();
     }

    /**
     * @dev Delay, in number of blocks, between the vote start and vote ends.
     */
    function votingPeriod() public view override(IRewarder, RewardSettings) returns (uint256) {
        return super.votingPeriod();
    }

    /**
     * @dev Required collateral, in tokens, a user must stake to upload
     */
    function requiredCollateral() public view override(IRewarder, RewardSettings) returns (uint256) {
        return super.requiredCollateral();
    }


    function eligibleRewards() public view returns(uint256) {
        return _underlying.balanceOf(address(this)) - heldCollateral;
    }

    function activeVotes() public view override returns (uint256){
        return totalActiveVotes;
    }

    /**
     * @dev Voting power of an `account` at a specific `blockNumber`.
     *
     * Note: this can be implemented in a number of ways, for example by reading the delegated balance from one (or
     * multiple), {ERC20Votes} tokens.
     */
    function getVotes(address account, uint256 blockNumber) public view override returns (uint256){
        return _underlying.getPastVotes(account, blockNumber);
    }


    /**
     * @dev Create a new proposal. Vote start once pending and flagging are passed and ends
     * {IRewarder-votingPeriod} blocks after the voting starts.
     */
    function propose(
        uint256 previousVersionIndex,
        address rewardee,
        string memory IPFS_CID
    ) public override returns(uint256 proposalId){

        require(!_upgrading, "Cannot upload to a deprecating reward contract");
        require(ICollaborator(address(_underlying)).ICOFinalized(), "ICO not yet finalized." );

        if(previousVersionIndex != 0){
            require(
                acceptsContract(
                    _storageInstance.getUploader(previousVersionIndex),
                    _storageInstance.getBlockNumber(previousVersionIndex)
                ), 
                "This project was not uploaded through an approved contract"
            );

        }


        
        SafeERC20.safeTransferFrom
        (
            _underlying,
            msg.sender, 
            address(this), 
            requiredCollateral()
        );

        uint256[] memory tempArray = new uint256[](1);
        tempArray[0] = previousVersionIndex;
        bytes32[] memory emptyData;
        uint256 postIndex = _storageInstance.uploadPost(tempArray, 0, rewardee, IPFS_CID, emptyData);

        heldCollateral += requiredCollateral();

        proposalIndex++;

        proposals[proposalIndex].state = ProposalState.Active;

        proposals[proposalIndex].previousVersionIndex = previousVersionIndex;
        proposals[proposalIndex].rewardee = rewardee;
        proposals[proposalIndex].IPFS_CID = IPFS_CID;
        
        proposals[proposalIndex].blockCreated = block.number;
        proposals[proposalIndex].collateral = requiredCollateral();
        proposals[proposalIndex].proposer = msg.sender;
        proposals[proposalIndex].postIndex = postIndex;

        _storageInstance.uploadProposal(
            proposalIndex, 
            postIndex,
            0,
            rewardee
        );

        return proposalIndex;
    }

    /**
     * @dev Flags an existing proposal. This prompts an internal vote on the legitimacy of the proposal,
     * after which the proposal will either continue to the general voting or end.
     * 
     * Emits a {ProposalFlagged} event.
     */
    function flagProposal(uint256 proposalId, string memory reason) public override{
        require(
            state(proposalId) == ProposalState.Active,
             "This proposal is not Active"
        );
        require(
            !previouslyFlagged(proposalId),
            "Proposal has already been flagged"
        );

        SafeERC20.safeTransferFrom
        (
            _underlying,
            msg.sender, 
            address(this), 
            proposals[proposalId].collateral
        );

        heldCollateral += proposals[proposalId].collateral;

        proposals[proposalId].state = ProposalState.Flagged;

        proposals[proposalId].flaggingData.flagger = msg.sender;
        proposals[proposalId].flaggingData.reason = reason;
        proposals[proposalId].flaggingData.blockFlagged = block.number;

        emit ProposalFlagged(proposalId, msg.sender, reason);
    }

    /**
     * @dev Called at the end of a proposal's flagging period 
     *
     * Emits a {ProposalVotingBegin} *OR* {ProposalBlocked} event.
     */
    function flagVerdict(uint256 proposalId) public override{
        require(
            state(proposalId) == ProposalState.Flagged,
             "This proposal is not flagged"
        );
        require(
            block.number - proposals[proposalId].flaggingData.blockFlagged >= flaggingPeriod(), 
            "Flagging vote has not finished yet."
        );

        uint256 approve = proposals[proposalId].flaggingData.approveVotes;
        uint256 disapprove = proposals[proposalId].flaggingData.disapproveVotes;

        if(approve > disapprove){
            // Activate proposal, return collateral to uploader, 
            // mark flagger's collateral for distribution, emit event
            proposals[proposalId].state = ProposalState.Active;
            _underlying.transfer(proposals[proposalId].proposer, proposals[proposalId].collateral);

            emit ProposalExonerated(proposalId);
        }else{
            // Block proposal, return collateral to flagger + reward, 
            // mark uploader's collateral for distribution, emit event
            proposals[proposalId].state = ProposalState.Blocked;
            _underlying.transfer(proposals[proposalId].flaggingData.flagger, 3*proposals[proposalId].collateral/2);

            totalActiveVotes -= approve;

            emit ProposalBlocked(proposalId, proposals[proposalId].flaggingData.reason);
        }

            proposals[proposalId].flaggingData.incentivesDue = proposals[proposalId].collateral/2;
            heldCollateral -= 3*proposals[proposalId].collateral/2;
    }


    /**
     * @dev Cast a vote on a flagged proposal
     *
     * Emits a {FlagVoteCast} event.
     */
    function castFlagVote(uint256 proposalId, bool support, string memory reason) public virtual override returns (uint256 balance){
        require(!hasVotedFlagged(proposalId, msg.sender), "User has already voted");
        require(proposals[proposalId].state == ProposalState.Flagged, "Proposal is not flagged");

        uint256 votes = getVotes(msg.sender, proposals[proposalId].flaggingData.blockFlagged);
        if(support){
                proposals[proposalId].flaggingData.approveVotes += votes;
        }else{
                proposals[proposalId].flaggingData.disapproveVotes += votes;
        }

        proposals[proposalId].flaggingData.hasVoted[msg.sender] = true;
        proposals[proposalId].flaggingData.voteAmount[msg.sender] = votes;
        proposals[proposalId].flaggingData.totalVotes += votes;

        incentives[msg.sender].push(proposalId);


        emit FlagVoteCast(msg.sender, proposalId, votes, support, reason);
        return votes;
    }

    /**
     * @dev Cast a vote
     *
     * Emits a {VoteCast} event.
     */
    function castVote(uint256 proposalId, bool support, string memory reason) public override returns (uint256 balance){
        require(!hasVoted(proposalId, msg.sender), "User has already voted");
        require(proposals[proposalId].state != ProposalState.Blocked, "Cannot vote on blocked proposal");
        uint256 votes = getVotes(msg.sender, proposals[proposalId].blockCreated);

        if(support){
            proposals[proposalId].approveVotes += votes;
            totalActiveVotes += votes;
        }else{
            proposals[proposalId].disapproveVotes += votes;
        }

        proposals[proposalId].hasVoted[msg.sender] = true;

        emit VoteCast(msg.sender, proposalId, votes, support, reason);
        return votes;
    }

    function previouslyFlagged(uint256 proposalId) public view override returns (bool) {
        return proposals[proposalId].flaggingData.blockFlagged != 0;
    }

    function currentVotes(uint256 proposalId) public view override returns(uint256 amount){
        uint256 votesFor = proposals[proposalId].approveVotes;
        uint256 votesAgainst = proposals[proposalId].disapproveVotes;

        if(votesFor == 0) return 0;
        return votesFor * votesFor / (votesFor + votesAgainst);
    }

    function totalVotes(uint256 proposalId) public view override returns(uint256 amount){
        uint256 voteSum = currentVotes(proposalId);

        uint256 currentIndex = proposals[proposalId].postIndex;

        while(_storageInstance.getPreviousVersionIndexes(currentIndex)[0] != 0){
            currentIndex = _storageInstance.getPreviousVersionIndexes(currentIndex)[0];
            voteSum += currentVotes(_storageInstance.getProposalIndex(currentIndex, address(this), 0));
        }
    
        return voteSum;

    }

    /**
     * @dev Collects the incentive awarded to participants of the moderation process
     *
     * Emits a {IncentivesCollected} event.
     */
    function collectIncentives() public override returns(uint256 incentiveAmount){
        require(incentives[msg.sender].length > 0, "User is not due any inventive tokens.");

        uint256 tokensDue;

        for(uint256 i = incentives[msg.sender].length; i >= 0; i--){
            uint256 currentProposal = incentives[msg.sender][i];
            if(proposals[currentProposal].state == ProposalState.Blocked || proposals[currentProposal].state == ProposalState.Rewarded){ 
                  uint256 summand =  
                    (
                        proposals[currentProposal].flaggingData.incentivesDue * 
                        proposals[currentProposal].flaggingData.voteAmount[msg.sender] / 
                        proposals[currentProposal].flaggingData.totalVotes
                    );

                    proposals[currentProposal].flaggingData.totalVotes -= proposals[currentProposal].flaggingData.voteAmount[msg.sender];
                    proposals[currentProposal].flaggingData.incentivesDue -= summand;

                    tokensDue += summand;

                    //Remove proposals who's incentives have been collected by the user
                    incentives[msg.sender][i] = incentives[msg.sender][incentives[msg.sender].length - 1];
                    incentives[msg.sender].pop();
            }
        }

       
        _underlying.transfer(msg.sender, tokensDue);
        heldCollateral -= tokensDue;

        emit IncentivesCollected(msg.sender, tokensDue);
        return tokensDue;
    }

        function incentivesDue(address user) public view returns(uint256 incentivesDue){
            uint256 tokensDue;

            for(uint256 i = incentives[user].length; i >= 0; i--){
                uint256 currentProposal = incentives[user][i];
                if(proposals[currentProposal].state == ProposalState.Blocked || proposals[currentProposal].state == ProposalState.Rewarded){ 
                    uint256 summand =  
                        (
                            proposals[currentProposal].flaggingData.incentivesDue * 
                            proposals[currentProposal].flaggingData.voteAmount[user] / 
                            proposals[currentProposal].flaggingData.totalVotes
                        );

                        tokensDue += summand;
                }
            }

            return tokensDue;
        }


    /**
     * @dev Rewards an Active proposal once the voting period ends and adds the
     * project to the storage tree
     *
     * Emits a {ProposalRewarded} event.
     */
    function rewardProposal(uint256 proposalId) public override returns(uint256 rewardsIssued){
        require(state(proposalId) == ProposalState.Active, "This propsal is not in the active phase");
        if(previouslyFlagged(proposalId)){
            require(block.number - proposals[proposalId].blockCreated > votingPeriod() + flaggingPeriod(), "This proposal has not finished its voting phase");
        }else{
            require(block.number - proposals[proposalId].blockCreated > votingPeriod(), "This proposal has not finished its voting phase");
             _underlying.transfer(proposals[proposalId].proposer, proposals[proposalId].collateral);
             heldCollateral -= proposals[proposalId].collateral;
        }
        if(proposals[proposalId].previousVersionIndex != 0){
            require(_storageInstance.getReward(proposals[proposalId].previousVersionIndex, address(this), 0) > 0);
        }
        
    
        proposals[proposalId].state = ProposalState.Rewarded;

        if(ICollaborator(address(_underlying)).lastMinted() < block.number){
            ICollaborator(address(_underlying)).sendTokens();
        }

        uint256 approve = proposals[proposalId].approveVotes;
        uint256 disapprove = proposals[proposalId].disapproveVotes;

        address target = ICollaborator(address(_underlying)).targetAddress();
        uint256 adjustedTotalVotes = _upgrading ? totalActiveVotes + IRewarder(target).activeVotes() : totalActiveVotes;

        totalActiveVotes -= approve;

        uint256 totalReward = 
            eligibleRewards() * 
            approve /
            adjustedTotalVotes *
            approve /
            (approve + disapprove);

        uint256 returnVar = totalReward;

        uint256 currentIndex = proposals[proposalId].postIndex;
        uint256 previousIndex;

        bytes32[] memory emptyData;
        _storageInstance.rewardPost(currentIndex, 0, proposalIndex, totalReward, emptyData);


        //REWARD PROPIGATION LOGIC
        while(_storageInstance.getPreviousVersionIndexes(currentIndex)[0] != 0){

            previousIndex = _storageInstance.getPreviousVersionIndexes(currentIndex)[0];
            uint256 previousIndexProposal = _storageInstance.getProposalIndex(previousIndex, address(this), 0);
            uint256 currentIndexProposal = _storageInstance.getProposalIndex(currentIndex, address(this), 0);
            // current reward = total reward * votes / (votes+average)
            uint256 currentReward = 
                totalReward * currentVotes(currentIndexProposal)
                 /
                    (currentVotes(currentIndexProposal) + 
                    totalVotes(previousIndexProposal) /  
                    _storageInstance.getEntryNumber(previousIndex, address(this), 0));

                totalReward -= currentReward;
                _underlying.transfer(_storageInstance.getRewardee(currentIndex), currentReward);
                currentIndex = _storageInstance.getPreviousVersionIndexes(currentIndex)[0];
        }

        _underlying.transfer(_storageInstance.getRewardee(currentIndex), totalReward);

        return returnVar;
    }

    function beginUpgrade() public override{
        require(!_upgrading, "Contract is already upgrading");
        require(ICollaborator(address(_underlying)).targetAddress() != address(this), "Contract not upgraded");

        _upgrading = true;
        upgradeStartBlock = block.number;
    }

    function upgrade() public override{
        require(_upgrading, "Contract not set for upgrade");
        require(block.number - upgradeStartBlock <= votingPeriod() + flaggingPeriod(), "Insufficient time since upgrade begin");
        _underlying.transfer(ICollaborator(address(_underlying)).targetAddress(), _underlying.balanceOf(address(this)) - heldCollateral);
        _upgradeFinalized = true;
    }

    function upgradeFinalized() public view override returns(bool){
        return _upgradeFinalized;
    }


}