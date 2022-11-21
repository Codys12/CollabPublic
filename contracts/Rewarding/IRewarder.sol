// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

abstract contract IRewarder is IERC165 {

    enum ProposalState {
        Active,
        Flagged,
        Blocked,
        Rewarded
    }


    /// @dev Emitted when a user flags a project proposal
    event ProposalFlagged(
        uint256 proposalId,
        address flagger,
        string reason
    );

    /// @dev Emitted when the voting phase begins for a project
    event ProposalBlocked(
        uint256 proposalId,
        string reason
    );

    /// @dev Emmited when a user collects the incentive for voting on a flagged project
    event IncentivesCollected(
        address user,
        uint256 amount
    );

    /// @dev Emitted when the a flagged proposal is recovered
    event ProposalExonerated(
        uint256 proposalId
    );

    /// @dev Emmited when a project proposal is rewarded
    event ProposalRewarded(
        uint256 proposalId, 
        uint256 projectIndex, 
        uint256 rewardsIssued);

    /// @dev Emmited when a user casts a vote on flagged proposal
    event FlagVoteCast(
        address indexed voter, 
        uint256 proposalId, 
        uint256 weight,
        bool support,
        string reason
    );

    /// @dev Emmited when a user casts a vote
    event VoteCast(
        address indexed voter, 
        uint256 indexed proposalId, 
        uint256 weight,
        bool indexed support,
        string reason
    );

    /**
     * @notice module:core
     * @dev Current state of a proposal, following Compound's convention
     */
    function state(uint256 proposalId) public view virtual returns (ProposalState);

    /**
     * @dev Returns the postIndex for given proposalId.
     */
    function postIndex(uint256 proposalId) public view virtual returns (uint256);

    /**
     * @dev Delay, in number of blocks, between project flagged and project voting begin (if proposal passed flagging)
     */
    function flaggingPeriod() public view virtual returns (uint256);

    /**
     * @dev Delay, in number of blocks, between the vote start and vote ends.
     */
    function votingPeriod() public view virtual returns (uint256);

    /**
     * @dev Required collateral, in tokens, a user must stake to upload
     */
    function requiredCollateral() public view virtual returns (uint256);

    /**
     * @dev Returns if a user is verified (used for quadratic voting)
     */
    function isVerified(address user) public view virtual returns (bool);

    /**
     * @dev Returns if a contract can be accepted and used as reference for previous
     * project versions. Takes in contract address and blockNumber of upload.
     */
    function acceptsContract(address version, uint256 blockNumber) public view virtual returns (bool);

    function acceptedVersions() public view virtual returns (address[] memory);

    function activeVotes() public view virtual returns (uint256);

    function beginUpgrade() public virtual;

    function upgradeFinalized() public view virtual returns(bool);

    function upgrade() public virtual;

    function currentVotes(uint256 proposalId) public view virtual returns(uint256 amount);

    function totalVotes(uint256 proposalId) public view virtual returns(uint256 amount);

    function proposer(uint256 proposalId) public view virtual returns(address account);
    /**
     * @dev Voting power of an `account` at a specific `blockNumber`.
     *
     * Note: this can be implemented in a number of ways, for example by reading the delegated balance from one (or
     * multiple), {ERC20Votes} tokens.
     */
    function getVotes(address account, uint256 blockNumber) public view virtual returns (uint256);

   /**
     * @dev Returns true if `account` has cast a vote on `proposalId`.
     */
    function hasVoted(uint256 proposalId, address account) public view virtual returns (bool);

   /**
     * @dev Returns true if `account` has cast a vote on a flagged `proposalId`.
     */
    function hasVotedFlagged(uint256 proposalId, address account) public view virtual returns (bool);

   /**
     * @dev Returns true if proposal at [proposalId] has been previously flagged
     */
    function previouslyFlagged(uint256 proposalId) public view virtual returns (bool);
    
    /**
     * @dev Create a new proposal. Vote start once pending and flagging are passed and ends
     * {IRewarder-votingPeriod} blocks after the voting starts.
     *
     * Emits a {ProposalCreated} event.
     */
    function propose(
        uint256 previousVersionIndex,
        address rewardee,
        string memory IPFS_CID
    ) public virtual returns(uint256 proposalId);


    /**
     * @dev Flags an existing proposal. This prompts an internal vote on the legitimacy of the proposal,
     * after which the proposal will either continue to the general voting or end.
     * 
     * Emits a {ProposalFlagged} event.
     */
    function flagProposal(
        uint256 proposalId,
        string memory reason
    ) public virtual;

    /**
     * @dev Called at the end of a proposal's flagging period 
     *
     * Emits a {ProposalExonerated} *OR* {ProposalBlocked} event.
     */
    function flagVerdict(
        uint256 proposalId
    ) public virtual;


    /**
     * @dev Rewards an Active proposal once the voting period ends and adds the
     * project to the storage tree
     *
     * Emits a {ProposalRewarded} event.
     */
    function rewardProposal(
        uint256 proposalId
    ) public virtual returns(uint256 rewardsIssued);

    /**
     * @dev Collects the incentives awarded to participants in the moderation process
     * Emits a {IncentivesCollected} event.
     */
    function collectIncentives() public virtual returns(uint256 incentiveAmount);

    /**
     * @dev Cast a vote on a flagged proposal
     *
     * Emits a {FlagVoteCast} event.
     */
    function castFlagVote(uint256 proposalId, bool support, string memory reason) public virtual returns (uint256 balance);

    /**
     * @dev Cast a vote
     *
     * Emits a {VoteCast} event.
     */
    function castVote(uint256 proposalId, bool support, string memory reason) public virtual returns (uint256 balance);



}