// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Rewarding/IRewarder.sol";
import "./Storage.sol";
import "./ICollaborator.sol";

    /**
     * @dev This is a public view function used to scan the Storage contract
     * and all relavent reward contracts for up to date voting data, then
     * sort and return the data in an array.
     */
contract Scanner{

    struct Data{
        uint256 location;
        uint256 votes;
        IRewarder.ProposalState state;
        bool previouslyFlagged;
        uint256 entryNum;
        address uploader;
        string IPFS_CID;

        uint256 votingPower;
        bool hasVoted;
    }

    function getVotes (
        address storageAddr,
        uint256[] memory proposalIndexes, 
        address[] memory addresses, 
        uint256 numReturns, 
        bool totalVotes,
        bool sort, 
        address perspective
    ) public view returns(Data[] memory data){

        require(proposalIndexes.length == addresses.length, "length mismatch");

        Data[] memory temp = new Data[](proposalIndexes.length);

        

        for(uint256 i = 0; i < proposalIndexes.length; i++){
            Data memory x;
            x.location = i;
        
            x.votes = 
            totalVotes 
                ? 
                IRewarder(addresses[i]).totalVotes(proposalIndexes[i]) 
                : 
                IRewarder(addresses[i]).currentVotes(proposalIndexes[i]);
            
            temp[i] = x;
        } 

        //Bubble sort {numReturns} times
        if(sort){
            for(uint256 i = 0; i < numReturns; i++){
                for(uint256 j = temp.length-1; j > 1; j--){
                    if(temp[j].votes > temp[j-1].votes){
                        Data memory x = temp[j-1];
                        temp[j-1] = temp[j];
                        temp[j] = x;
                    }
                }
            }
        }

       Data[] memory returnArr = new Data[](numReturns);

       for(uint256 i = 0; i < numReturns; i++){


        returnArr[i] = temp[i];
        uint256 proposalId = proposalIndexes[returnArr[i].location];
        address rewarder = addresses[returnArr[i].location];
        uint256 postIndex = IRewarder(rewarder).postIndex(proposalId);

        returnArr[i].state = IRewarder(rewarder).state(proposalId);
        returnArr[i].previouslyFlagged = IRewarder(rewarder).previouslyFlagged(proposalId);
        returnArr[i].entryNum = Storage(storageAddr).getEntryNumber(
            postIndex, 
            rewarder, 
            0
        );
        returnArr[i].uploader = IRewarder(rewarder).proposer(proposalId);
        returnArr[i].IPFS_CID = Storage(storageAddr).getIPFSCID(postIndex);
        
        if(perspective != 0x0000000000000000000000000000000000000000){
            uint256 uploadBlock = Storage(storageAddr).getBlockNumber(postIndex);
            returnArr[i].votingPower = IRewarder(rewarder).getVotes(perspective, uploadBlock);
            returnArr[i].hasVoted = IRewarder(rewarder).hasVoted(proposalId, perspective);
        }
        

       }

       return returnArr;

    }



}