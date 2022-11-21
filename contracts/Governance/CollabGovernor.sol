// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./RequirePayment.sol";
import "./GovernorSettings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorPreventLateQuorum.sol";

/// @title A governance contract for the Collaberator platform complient with openzeppelin governance standard
contract CollabGovernor is Governor, RequirePayment, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, GovernorTimelockControl, GovernorPreventLateQuorum {
   
   uint256 BLOCK_TIME = 12000; //12 second block time
    constructor(address _token, address _timelock)
        Governor("CollabGovernor")
        RequirePayment(_token, address(_timelock))
        GovernorSettings(1 /* 1 block */, 1000*60*60*24*7/BLOCK_TIME /* 1 week */, 0, 100e18 /*100 tokens*/, 20e18 /*20 percent max Change*/, 1000*60*60*24*7/BLOCK_TIME /* 1 week */)
        GovernorVotes(IVotes(_token))
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(TimelockController(payable(_timelock)))
        GovernorPreventLateQuorum(uint64(1000*60*60*24*3/BLOCK_TIME)) //Extends voting by 3 days if quorum is reached
    {}

    // The following functions are overrides required by Solidity.


    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function proposalCost()
        public
        view
        override(GovernorSettings, RequirePayment)
        returns (uint256)
    {
        return super.proposalCost();
    }

    function proposalDeadline(uint256 proposalId) 
        public 
        view 
        virtual
        override(IGovernor, Governor, GovernorPreventLateQuorum) 
        returns (uint256)
    {
        return super.proposalDeadline(proposalId);
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public
        override(Governor, IGovernor, RequirePayment)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params) 
        internal 
        virtual 
        override(Governor, GovernorPreventLateQuorum)
        returns (uint256)
    {
        return super._castVote(proposalId, account, support, reason, params);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}