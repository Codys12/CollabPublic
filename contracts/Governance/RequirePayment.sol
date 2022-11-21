// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Extension of {Governor} for requireing payment on proposal.
 *
 */
abstract contract RequirePayment is Governor {

    IERC20  private _underlying;
    address private _target;

    /**
     * @dev Initialize the payment parameters.
     */
    constructor(
        address underlying,
        address target
    ) {
        _underlying = ERC20(underlying);
        _target = target;
    }

    //function containing the cost of one operation in a proposal meant to be overridden in settings
    function proposalCost() public view virtual returns (uint256);

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        SafeERC20.safeTransferFrom
        (
            _underlying,
            msg.sender, 
            _target, 
            calculateProposalCost(targets, values, calldatas, description)
        );
        return super.propose(targets, values, calldatas, description);
    }

    function calculateProposalCost(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual returns (uint256) {
        return targets.length * proposalCost();
    }

}
