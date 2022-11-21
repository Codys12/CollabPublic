// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Distribute {

    address public deployer;
    address public tokenAddress = 0x978867e9aC04688f7AbB70ffF3dd48e7ea8Bd4Be;
    mapping(uint256 => bool) claimed;

    constructor(){
        deployer = msg.sender;
    }

    function hasBeenClaimed(uint256 slot) public view returns(bool){
        return claimed[slot];
    }

    function claim(uint256 slot, address recipient) public{
        
        require(!hasBeenClaimed(slot), "slot has already been claimed");
        require(msg.sender == deployer);
        claimed[slot] = true;
        IERC20(tokenAddress).transfer(recipient, 1000 ether);
    }

}