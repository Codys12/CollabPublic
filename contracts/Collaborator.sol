// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Collaborator is ERC20, ERC20Permit, ERC20Votes, Ownable {

    uint256 BLOCK_TIME = 12000; //12 second block time
    uint256 public INITIAL_COST_MULTIPLIER = 1 ether;
    uint256 public deploymentBlock; //The block on which the contract was deployed
    uint256 public ICOLength = 1000*60*20/BLOCK_TIME; // 20min //1249920; //The length of the ICO in blocks (~1 month) using average block time of 15s CHANGE THIS BACK AFTER TESTING
    bool    public ICOFinalized; //If the ICO has been finished and initial parameters set
    bool    public ownershipTransferUsed;

    uint256 private _mintRate; //The rate of minting of new tokens per block
    uint256 private _maxChange;  //The maximum allowable change (percent * 1e18)
    uint256 private _changeTime; //The rate at which parameters can be changed (in blocks)

    address private _targetAddress; //The address where the tokens will be sent

    //Keeps track of the last time contract parameters were changed
    uint256 private _lastChangedMintRate;
    uint256 private _lastChangedMaxChange;
    uint256 private _lastChangedChangeTime;
    uint256 private _lastChangedTargetAddress;

    uint256 private _lastMinted;

    event MintRateSet(uint256 oldMintRate, uint256 newMintRate);
    event MaxChangeSet(uint256 oldMaxChange, uint256 newMaxChange);
    event ChangeTimeSet(uint256 oldChangeTime, uint256 newChangeTime);
    event TargetAddressSet(address oldTargetAddress, address newTargetAddress);


    constructor() ERC20("Collaborator", "COLLAB") ERC20Permit("Collaborator") Ownable(){
        deploymentBlock = block.number;
        ICOFinalized = false;

        _setMaxChange(20e18); // initialize max change to 20%
        _setChangeTime(1000*60*60*24*7/BLOCK_TIME); // initialize change time to ~1 week
    }


    function percentDifference(uint256 x, uint256 y) pure public returns(uint256){
        uint256 numerator = x>y ? (x-y) : (y-x);
        uint256 denominator = x>y ? y : x;
        numerator *= 1e20; //Convert to percent and allow for division
        return numerator / denominator;
    }

    modifier inICO (){
        require(block.number - deploymentBlock <= ICOLength);
        _;
    }

    modifier ownershipModifier (){
        require(!ownershipTransferUsed, "Ownership already set");
        ownershipTransferUsed = true;
        _;
    }

    function mintRate() public view returns(uint256) {
        return _mintRate;
    }

    function maxChange() public view returns(uint256) {
        return _maxChange;
    }

    function changeTime() public view returns(uint256) {
        return _changeTime;
    }

    function lastMinted() public view returns(uint256) {
        return _lastMinted;
    }

    function targetAddress() public view returns(address) {
        return _targetAddress;
    }

    function buyTokens() payable public inICO {
        _mint(msg.sender, msg.value * 1 ether /* 100 */); //Mints tokens at a rate 100:1 tokens to Ether CHANGE THIS BACK AFTER TESTING
        _delegate(msg.sender, msg.sender);
    }

    function finalizeICO() public{
        require(!ICOFinalized, "ICO already finalized");
        require(block.number - deploymentBlock >= ICOLength, "ICO period not passed");
        //10% transfer of funds
        //Extra minting logic
        _lastMinted = block.number;
        _setMintRate((uint256)(1000000 ether) / (1000*60*60*24*31/BLOCK_TIME /*number of blocks in a mont*/) /*totalSupply() / 3*/); //Sets initial mint rate to 1/3 average ICO rate CHANGE THIS BACK AFTER TESTING
        ICOFinalized = true;
    }

    function exchangeTokens(uint256 amount) public{
        require(balanceOf(msg.sender) >= amount, "amount exceeds balance");
        uint256 amountDue = address(this).balance * amount / totalSupply();
        _setMintRate(mintRate() * (totalSupply() - amount) / totalSupply());
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amountDue);
    }

    function sendTokens() public{
        require(block.number - _lastMinted > 0, "Must be at least one block between mints");
        require(ICOFinalized);
        uint256 numBlocks = block.number - _lastMinted;
        _lastMinted = block.number;

        _mint(_targetAddress, mintRate() * numBlocks);

    }


    function setMintRate(uint256 newMintRate) public onlyOwner{
        require(percentDifference(_mintRate, newMintRate) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedMintRate >= changeTime(), "Not enough time has passed since this parameter was last changed");
        _lastChangedMintRate = block.number;
        _setMintRate(newMintRate);
    }

    function setMaxChange(uint256 newMaxChange) public onlyOwner{
        require(percentDifference(_maxChange, newMaxChange) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedMaxChange >= changeTime(), "Not enough time has passed since this parameter was last changed");
        _lastChangedMaxChange = block.number;
        _setMaxChange(newMaxChange);
    }

    function setChangeTime(uint256 newChangeTime) public onlyOwner{
        require(percentDifference(_changeTime, newChangeTime) < maxChange(), "Parameter change exceeds max allowed percent change");
        require(block.number - _lastChangedChangeTime >= changeTime(), "Not enough time has passed since this parameter was last changed");
        _lastChangedChangeTime = block.number;
        _setChangeTime(newChangeTime);
    }

    function setTargetAddress(address newTargetAddress) public onlyOwner{
        require(block.number - _lastChangedTargetAddress >= changeTime(), "Not enough time has passed since this parameter was last changed");
        _lastChangedTargetAddress = block.number;
        _setTargetAddress(newTargetAddress);
    }



    function _setMintRate(uint256 newMintRate) internal {
        emit MintRateSet(_mintRate, newMintRate);
        _mintRate = newMintRate;
    }

    function _setMaxChange(uint256 newMaxChange) internal {
        emit MaxChangeSet(_maxChange, newMaxChange);
        _maxChange = newMaxChange;
    }

    function _setChangeTime(uint256 newChangeTime) internal {
        emit ChangeTimeSet(_changeTime, newChangeTime);
        _changeTime = newChangeTime;
    }

    function _setTargetAddress(address newTargetAddress) internal {
        emit TargetAddressSet(_targetAddress, newTargetAddress);
        _targetAddress = newTargetAddress;
    }



    // The following functions are overrides required by Solidity.
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function transferOwnership(address newOwner) public override ownershipModifier {
        super.transferOwnership(newOwner);
    }
}