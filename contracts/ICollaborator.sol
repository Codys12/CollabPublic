// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

abstract contract ICollaborator is ERC20Votes{

    function lastMinted() public virtual view returns(uint256);

    function sendTokens() public virtual;

    function targetAddress() public view virtual returns(address);

    function ICOFinalized() public view virtual returns(bool);

}