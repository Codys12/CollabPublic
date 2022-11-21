// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (governance/extensions/GovernorSettings.sol)

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/governance/Governor.sol";

/**
 * @dev Extension of {Governor} for settings updatable through governance.
 *
 * _Available since v4.4._
 */
abstract contract GovernorSettings is Governor {
    uint256 private _votingDelay;
    uint256 private _votingPeriod;
    uint256 private _proposalThreshold;
    uint256 private _proposalCost;
    uint256 private _maxChange;
    uint256 private _changeTime;

    //Keeps track of the last time contract parameters were changed
    uint256 private _lastChangedVotingDelay;
    uint256 private _lastChangedVotingPeriod;
    uint256 private _lastChangedProposalThreshold;
    uint256 private _lastChangedProposalCost;
    uint256 private _lastChangedMaxChange;
    uint256 private _lastChangedChangeTime;

    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event ProposalCostSet(uint256 oldProposalCost, uint256 newProposalCost);
    event MaxChangeSet(uint256 oldMaxChange, uint256 newMaxChange);
    event ChangeTimeSet(uint256 oldChangeTime, uint256 newChangeTime);

    /**
     * @dev Initialize the governance parameters.
     */
    constructor(
        uint256 initialVotingDelay,
        uint256 initialVotingPeriod,
        uint256 initialProposalThreshold,
        uint256 initialProposalCost,
        uint256 initialMaxChange,
        uint256 initialChangeTime
    ) {
        _setVotingDelay(initialVotingDelay);
        _setVotingPeriod(initialVotingPeriod);
        _setProposalThreshold(initialProposalThreshold);
        _setProposalCost(initialProposalCost);
        _setMaxChange(initialMaxChange);
        _setChangeTime(initialChangeTime);
    }
    

    function percentDifference(uint256 x, uint256 y) pure public returns(uint256){
        uint256 numerator = x>y ? (x-y) : (y-x);
        uint256 denominator = x>y ? y : x;
        numerator *= 1e20; //Convert to percent and allow for division
        return numerator / denominator;
    }

    /**
     * @dev See {IGovernor-votingDelay}.
     */
    function votingDelay() public view virtual override returns (uint256) {
        return _votingDelay;
    }

    /**
     * @dev See {IGovernor-votingPeriod}.
     */
    function votingPeriod() public view virtual override returns (uint256) {
        return _votingPeriod;
    }

    /**
     * @dev See {Governor-proposalThreshold}.
     */
    function proposalThreshold() public view virtual override returns (uint256) {
        return _proposalThreshold;
    }

    function proposalCost() public view virtual returns (uint256) {
        return _proposalCost;
    }

    function maxChange() public view virtual returns (uint256) {
        return _maxChange;
    }

    function changeTime() public view virtual returns (uint256) {
        return _changeTime;
    }

    /**
     * @dev Update the voting delay. This operation can only be performed through a governance proposal.
     *
     * Emits a {VotingDelaySet} event.
     */
    function setVotingDelay(uint256 newVotingDelay) public virtual onlyGovernance {
        require(percentDifference(_votingDelay, newVotingDelay) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedVotingDelay > changeTime(), "Not enough time has passed since this parameter was last changed");
        _setVotingDelay(newVotingDelay);
    }

    /**
     * @dev Update the voting period. This operation can only be performed through a governance proposal.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function setVotingPeriod(uint256 newVotingPeriod) public virtual onlyGovernance {
        require(percentDifference(_votingPeriod, newVotingPeriod) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedVotingPeriod > changeTime(), "Not enough time has passed since this parameter was last changed");
        _setVotingPeriod(newVotingPeriod);
    }

    /**
     * @dev Update the proposal threshold. This operation can only be performed through a governance proposal.
     *
     * Emits a {ProposalThresholdSet} event.
     */
    function setProposalThreshold(uint256 newProposalThreshold) public virtual onlyGovernance {
        require(percentDifference(_proposalThreshold, newProposalThreshold) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedProposalThreshold > changeTime(), "Not enough time has passed since this parameter was last changed");
        _setProposalThreshold(newProposalThreshold);
    }

    /**
     * @dev Update the proposalcost. This operation can only be performed through a governance proposal.
     *
     * Emits a {ProposalCostSet} event.
     */
    function setProposalCost(uint256 newProposalCost) public virtual onlyGovernance {
        require(percentDifference(_proposalCost, newProposalCost) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedProposalCost > changeTime(), "Not enough time has passed since this parameter was last changed");
        _setProposalCost(newProposalCost);
    }

    /**
     * @dev Update the maximum allowed change. This operation can only be performed through a governance proposal.
     *
     * Emits a {MaxChangeSet} event.
     */
    function setMaxChange(uint256 newMaxChange) public virtual onlyGovernance {
        require(percentDifference(_maxChange, newMaxChange) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedMaxChange > changeTime(), "Not enough time has passed since this parameter was last changed");
        _setMaxChange(newMaxChange);
    }

    /**
     * @dev Update the minimum required time for a parameter to change. This operation can only be performed through a governance proposal.
     *
     * Emits a {ChangeTimeSet} event.
     */
    function setChangeTime(uint256 newChangeTime) public virtual onlyGovernance {
        require(percentDifference(_changeTime, newChangeTime) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedChangeTime > changeTime(), "Not enough time has passed since this parameter was last changed");
        _setChangeTime(newChangeTime);
    }


    /**
     * @dev Internal setter for the voting delay.
     *
     * Emits a {VotingDelaySet} event.
     */
    function _setVotingDelay(uint256 newVotingDelay) internal virtual {
        emit VotingDelaySet(_votingDelay, newVotingDelay);
        _lastChangedVotingDelay = block.number;
        _votingDelay = newVotingDelay;
    }

    /**
     * @dev Internal setter for the voting period.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function _setVotingPeriod(uint256 newVotingPeriod) internal virtual {
        // voting period must be at least one block long
        require(newVotingPeriod > 0, "GovernorSettings: voting period too low");
        emit VotingPeriodSet(_votingPeriod, newVotingPeriod);
        _lastChangedVotingPeriod = block.number;
        _votingPeriod = newVotingPeriod;
    }

    /**
     * @dev Internal setter for the proposal threshold.
     *
     * Emits a {ProposalThresholdSet} event.
     */
    function _setProposalThreshold(uint256 newProposalThreshold) internal virtual {
        emit ProposalThresholdSet(_proposalThreshold, newProposalThreshold);
        _lastChangedProposalThreshold = block.number;
        _proposalThreshold = newProposalThreshold;
    }

    /**
     * @dev Internal setter for the proposal cost
     *
     * Emits a {ProposalCostSet} event.
     */
    function _setProposalCost(uint256 newProposalCost) internal virtual {
        emit ProposalCostSet(_proposalCost, newProposalCost);
        _lastChangedProposalCost = block.number;
        _proposalCost = newProposalCost;
    }

    /**
     * @dev Internal setter for the max change.
     *
     * Emits a {MaxChangeSet} event.
     */
    function _setMaxChange(uint256 newMaxChange) internal virtual {
        emit MaxChangeSet(_maxChange, newMaxChange);
        _lastChangedMaxChange = block.number;
        _maxChange = newMaxChange;
    }

    /**
     * @dev Internal setter for the change time.
     *
     * Emits a {ChangeTimeSet} event.
     */
     function _setChangeTime(uint256 newChangeTime) internal virtual {
         emit ChangeTimeSet(_changeTime, newChangeTime);
         _lastChangedChangeTime = block.number;
         _changeTime = newChangeTime;
     }
}

