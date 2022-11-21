// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


/**
 * @dev Extension of {RewardContract} for settings updatable through governance.
 */
abstract contract RewardSettings {

    uint256 private _flaggingPeriod;
    uint256 private _votingPeriod;
    uint256 private _requiredCollateral;
    uint256 private _maxChange;
    uint256 private _changeTime;

    //Keep track of the last time parameters were changed
    uint256 private _lastChangedFlaggingPeriod;
    uint256 private _lastChangedVotingPeriod;
    uint256 private _lastChangedRequiredCollateral;
    uint256 private _lastChangedMaxChange;
    uint256 private _lastChangedChangeTime;

    address private _governance;


    event FlaggingDelaySet(uint256 oldFlaggingDelay, uint256 newFlaggingDelay);
    event FlaggingPeriodSet(uint256 oldFlaggingPeriod, uint256 newFlaggingPeriod);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event RequiredCollateralSet(uint256 oldRequiredCollateral, uint256 newRequiredCollateral);
    event MaxChangeSet(uint256 oldMaxChange, uint256 newMaxChange);
    event ChangeTimeSet(uint256 oldChangeTime, uint256 newChangeTime);

    /**
     * @dev Initialize the reward parameters.
     */
    constructor(
        address governance,
        uint256 initialFlaggingPeriod,
        uint256 initialVotingPeriod,
        uint256 initialRequiredCollateral,
        uint256 initialMaxChange,
        uint256 initialChangeTime
    ) {
        _governance = governance;
        _setFlaggingPeriod(initialFlaggingPeriod);
        _setVotingPeriod(initialVotingPeriod);
        _setRequiredCollateral(initialRequiredCollateral);
        _setMaxChange(initialMaxChange);
        _setChangeTime(initialChangeTime);
    }

    modifier onlyGovernance(){
        require(msg.sender == _governance);
        _;
    }
    

    function percentDifference(uint256 x, uint256 y) pure public returns(uint256){
        uint256 numerator = x>y ? (x-y) : (y-x);
        uint256 denominator = x>y ? y : x;
        numerator *= 1e20; //Convert to percent and allow for division
        return numerator / denominator;
    }


    /**
     * @dev See {IRewarder-flaggingPeriod}.
     */
    function flaggingPeriod() public view virtual returns (uint256) {
        return _flaggingPeriod;
    }

    /**
     * @dev See {IRewarder-votingPeriod}.
     */
    function votingPeriod() public view virtual returns (uint256) {
        return _votingPeriod;
    }

    /**
     * @dev See {IRewarder-requiredCollateral}.
     */
    function requiredCollateral() public view virtual returns (uint256) {
        return _requiredCollateral;
    }

    function maxChange() public view virtual returns (uint256) {
        return _maxChange;
    }

    function changeTime() public view virtual returns (uint256) {
        return _changeTime;
    }


    /**
     * @dev Update the flagging period. This operation can only be performed through a governance proposal.
     *
     * Emits a {FlaggingPeriodSet} event.
     */
    function setFlaggingPeriod(uint256 newFlaggingPeriod) public virtual onlyGovernance {
        require(percentDifference(_flaggingPeriod, newFlaggingPeriod) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedFlaggingPeriod > changeTime(), "Not enough time has passed since this parameter was last changed");
        
        _setFlaggingPeriod(newFlaggingPeriod);
    }

    /**
     * @dev Update the voting period. This operation can only be performed through a governance proposal.
     *
     * Emits a {setVotingPeriodSet} event.
     */
    function setVotingPeriod(uint256 newVotingPeriod) public virtual onlyGovernance {
        require(percentDifference(_votingPeriod, newVotingPeriod) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedVotingPeriod > changeTime(), "Not enough time has passed since this parameter was last changed");
        _setVotingPeriod(newVotingPeriod);
    }

    /**
     * @dev Update the required collateral. This operation can only be performed through a governance proposal.
     *
     * Emits a {RequiredCollateralSet} event.
     */
    function setRequiredCollateral(uint256 newRequiredCollateral) public virtual onlyGovernance {
        require(percentDifference(_requiredCollateral, newRequiredCollateral) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedRequiredCollateral > changeTime(), "Not enough time has passed since this parameter was last changed");
        _setRequiredCollateral(newRequiredCollateral);
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
     * @dev Update the minimum required time for changing a parameter. This operation can only be performed through a governance proposal.
     *
     * Emits a {ChangeTimeSet} event.
     */
    function setChangeTime(uint256 newChangeTime) public virtual onlyGovernance {
        require(percentDifference(_changeTime, newChangeTime) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedChangeTime > changeTime(), "Not enough time has passed since this parameter was last changed");
        _setChangeTime(newChangeTime);
    }


    /**
     * @dev Internal setter for the flagging period.
     *
     * Emits a {FlaggingPeriodSet} event.
     */
    function _setFlaggingPeriod(uint256 newFlaggingPeriod) internal virtual {
        emit FlaggingPeriodSet(_flaggingPeriod, newFlaggingPeriod);
        _lastChangedFlaggingPeriod = block.number;
        _flaggingPeriod = newFlaggingPeriod;
    }

    /**
     * @dev Internal setter for the voting period.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function _setVotingPeriod(uint256 newVotingPeriod) internal virtual {
        emit VotingPeriodSet(_votingPeriod, newVotingPeriod);
        _lastChangedVotingPeriod = block.number;
        _votingPeriod = newVotingPeriod;
    }

    /**
     * @dev Internal setter for the required collateral
     *
     * Emits a {RequiredCollateralSet} event.
     */
    function _setRequiredCollateral(uint256 newRequiredCollateral) internal virtual {
        emit RequiredCollateralSet(_requiredCollateral, newRequiredCollateral);
        _lastChangedRequiredCollateral = block.number;
        _requiredCollateral = newRequiredCollateral;
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
