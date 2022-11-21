// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract Timelock is TimelockController {

    address[] proposers;
    address[] executors;

    constructor() TimelockController(86400000, proposers, executors) {}

}