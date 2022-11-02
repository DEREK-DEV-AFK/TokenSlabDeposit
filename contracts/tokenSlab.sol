pragma solidity ^0.8.0; // SPDX-License-Identifier: UNLICENSED

import "./tokens/ERC20.sol";

/*
 * SLAB TOKEN CAPACITY INFO
 * Slab 0 = 100 Token
 * Slab 1 = 200 Token
 * Slab 2 = 300 Token
 * Slab 3 = 400 Token
 * Slab 4 = 500 Token
 */

contract tokenSlabDeposit {

    uint8 public currentSlab; // by default 0 : bytes 1 : slot 0
    uint8 public maxSlab; // will be inisialize when deploying : bytes 1 : slot 0
    bool inProgress = false; // for reentrancy : 1 bytes : slot 0

    ERC20 tokenAccepted; // token which will be accepted

    // struct to store slab storeage info
    struct slabInfo {
        uint256 slabTokenSpace;
        uint256 balanceTokenSpace;
    }

    // mapping for storing token deposit by specific user in specific slab
    mapping(uint256 => mapping(address => uint256)) tokenDepositUserInfo;
    // mapping for storing specific slab info
    mapping(uint256 => slabInfo) specificSlabInfo;

    constructor(uint8 _maxSlab, address _tokenAccepted) {
        uint size;
        assembly { size := extcodesize(_tokenAccepted) }
        require(size > 0,"Deployer: Address is not an contract");
        maxSlab = _maxSlab;
        tokenAccepted = ERC20(_tokenAccepted);
        //require(tokenAccepted.decimals(), "Deployer: Address is not an ERC20 token");
    }

    modifier reentrancy() {
        require(!inProgress,"Reentrancy: already in progress");
        _;
    }

    event deposit(address _depositer, uint256 _amount, uint8 _slabNo);
    event slabChange(uint8 _newSlabNo);

    /**
      * @dev deposit Token  
      * @param tokenAmount amount to transfer with
      * @return bool status of function succeed or not
      *
      * Requirements:
      *    allowance from sender to this contract to transfer token
      */
    function depositToken(uint256 tokenAmount) external reentrancy returns(bool){
        require(tokenAccepted.allowance(msg.sender,address(this)) >= tokenAmount,"depositToken: please approve contract to transfer token");
        
        uint8 _currentSlab = currentSlab; // gas saving, by not calling global variable again and again.

        // checking current slab status
        if(specificSlabInfo[_currentSlab].slabTokenSpace == 0){
            initialize(_currentSlab);

        } else if(specificSlabInfo[currentSlab].balanceTokenSpace == specificSlabInfo[currentSlab].slabTokenSpace){
            if(_currentSlab == maxSlab){
                revert("depositToken: all slabs are full");
            }
            changeSlab();
            initialize(currentSlab);
        }

        // check the current slab capacity
        uint256 spaceLeftInCurrentSlab = specificSlabInfo[currentSlab].slabTokenSpace - specificSlabInfo[currentSlab].balanceTokenSpace;
        uint256 tokenToAdd = tokenAmount < spaceLeftInCurrentSlab ? tokenAmount : spaceLeftInCurrentSlab;

        // transfering token from sender to this contract 
        tokenAccepted.transferFrom(msg.sender, address(this), tokenToAdd);

        // update user data
        tokenDepositUserInfo[currentSlab][msg.sender] += tokenToAdd;

        // updating slab data
        specificSlabInfo[currentSlab].balanceTokenSpace += tokenToAdd;

        emit deposit(msg.sender, tokenAmount,_currentSlab);

        return true;
    }

    /**
      * @dev get token deposited by user in this contract
      * @return uint256 value of token deposited by the user
      */
    function UserTotalDepositInfo(address user) external view returns(uint256){
        uint256 totaltokenDeposited = 0;
        
        for(uint8 i = 0 ; i <= currentSlab ; ++i){ // gas saving by using ++i instead of i++
            totaltokenDeposited += tokenDepositUserInfo[i][user];
        }
        return totaltokenDeposited;
    }

    /**
      * @dev returns the latest slab no which user have deposited
      * @param user the user whose slab no we have to find
      * @return latestSlabDeposited value is of slab no which user has deposited token in
      */
    function userSlabsDepositInfo(address user) external view returns(uint256 latestSlabDeposited){
        bool hasDeposited = false;
        for(uint8 i = 0 ; i <= currentSlab ; ++i){
            if(tokenDepositUserInfo[i][user] > 0){
                hasDeposited = true;
                latestSlabDeposited = i;
            }
        }
        require(hasDeposited,"userSlabsDepositInfo: user has not deposited");
        return latestSlabDeposited;
    }

    /**
      * @dev getter function to get info of specific slap
      * @param _slabNo slab no
      * @return _slabTokenSpace returns the slab's token capacity
      * @return _balanceTokenSpace returns current balance of that slab
      */
    function SlabInfo(uint8 _slabNo) external view returns(uint256 _slabTokenSpace, uint256 _balanceTokenSpace){
        // saving data from mapping
        slabInfo memory data = specificSlabInfo[_slabNo];

        return(data.slabTokenSpace, data.balanceTokenSpace);
    }

    /**
      * @dev initialize slab for the first time 
      * @param slabNo current slab no
      */
    function initialize(uint8 slabNo) private {
        uint8 decimals = tokenAccepted.decimals();
        uint256 tokenCapacity = (slabNo + 1) * 100 * 10 ** decimals ; // logic for calculating capacity
        specificSlabInfo[slabNo].slabTokenSpace = tokenCapacity;
    }

    /**
      * @dev changing the current slab
      */
    function changeSlab() private {
        currentSlab = currentSlab + 1;
        emit slabChange(currentSlab);
    }
}