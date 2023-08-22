// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract is Ownable {

    //each stake will have start time and amount data
    struct Stake {
        uint amount;
        uint startTime;
    }

    //stakers and their amount will be saved in stakes mapping
    mapping(address => Stake) public stakes;

    //state variables: tokenA and tokenB addresses, to be assigned by constructor
    address public tokenA;
    address public tokenB;

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    //events for token staking and unstaking
    event Staked(address indexed user, uint amount, address indexed token);
    event Withdrawn(address indexed user, uint256 amount, address indexed token);

    modifier hasStake() {
        require(stakes[msg.sender].amount > 0, "No stake available");
        _;
    }

    function stake(uint _amount, address _token) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_token == tokenA || _token == tokenB, "invalid token address");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        if(stakes[msg.sender].amount == 0) {

        }
    }


    function stake(uint256 _amount, address _token) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_token == tokenA || _token == tokenB, "Invalid token");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender].startTime = block.timestamp;
        }

        stakes[msg.sender].amount += _amount;

        emit Staked(msg.sender, _amount, _token);
    }

    function withdraw(address _token) external hasStake {
        require(_token == tokenA || _token == tokenB, "Invalid token");

        uint256 stakedAmount = stakes[msg.sender].amount;
        uint256 stakingDuration = block.timestamp - stakes[msg.sender].startTime;

        uint256 reward = calculateReward(stakedAmount, stakingDuration);

        stakes[msg.sender].amount = 0;

        IERC20(_token).transfer(msg.sender, stakedAmount + reward);

        emit Withdrawn(msg.sender, stakedAmount + reward, _token);
    }

    function calculateReward(uint256 _amount, uint256 _duration) internal pure returns (uint256) {
        // This is a simplified example, you can implement your own reward calculation logic
        return (_amount * _duration) / 1000; // Dummy formula
    }

    function getUserStake(address _user) external view returns (uint256) {
        return stakes[_user].amount;
    }

    function getUserStakingStartTime(address _user) external view returns (uint256) {
        return stakes[_user].startTime;
    }
}


contract TokenAStaking is Ownable {
    event Staked(address stakerAddress, uint amount);
    event Unstaked(address unstaker, uint index);
    event RewardClaimed(address claimer, uint index, uint amount);
    event RewardStaked(address rewardStaker, uint index, uint amount);
    event DecreasedStake(address stakeDecreeaser, uint index, uint decreaseAmount);

    // --- STATE VARIABLES ---
    //Each stake will have data presented here.
    struct StakeDetails {
        uint amount;
        uint startTime;
    }
    //Main mapping. A person can stake many times. Each stake will have record. And each stake
    //will be saved inside StakeDetails array.
    mapping(address => StakeDetails[]) public StakeDetailsMapping;
    //keeping track of how much staked. Will be used for control checks.
    mapping(address => uint) public stakers;
    //Keeping track total staked amount in the system.
    uint public totalStaked;
    //tokenA address to be assigned by constructor
    IERC20 public tokenA;

    // --- MODIFIERS ---
    error NotStaker(address caller, string message);
    modifier onlyStakers() {
        if(stakers[msg.sender] == 0 ) {
            revert NotStaker(msg.sender, "you have 0 stake amount");
        }
        _;
    }

    // SUPPORT FUNCTION 1: apy and apy update function. onlyOwner can call function.
    // 1 means 1% apy.
    uint public apy = 1;
    function updateApy(uint _newApy) external onlyOwner {
        require(_newApy != 0 && _newApy < 30, "apy should have reasonable limits");
        apy = _newApy;
    }

    // SUPPORT FUNCTION 2: constructor assigning token address
    constructor(address _tokenA) {
        tokenA = IERC20(_tokenA);
    }

    // SUPPORT FUNCTION 3: calculate stake reward
    // Reward will be calculated on a daily basis on compound interest formula.
    // startTime will be obtained from staking record. Endtime will be function block.timestamp
    function calculateYield(uint _amount, uint _startTime) internal view returns(uint) {
        uint principal = _amount;
        //getting number of days stake remained in the system
        uint numberDays = (block.timestamp - _startTime) / 1 days;
        //calculating reward(yield) on a daily basis
        for(uint i=0; i<numberDays; i++) {
            principal += principal * (apy/365);
        }
        uint reward = principal - _amount;
        return reward;
    }   

    //user can claim reward for his/her stakes. To specify which stake, user needs to enter an index number
    //for the  StakeDetails[] array. User can specify his choice on the frontend website, and later web3
    //functions will convey the index number to the function below.
    function claimReward(address _to, uint _index) external onlyStakers {
        //input checks
        require(_to != address(0), "Cannot claim from address 0");

        uint stakeAmount = StakeDetailsMapping[msg.sender][_index].amount;
        uint stakeTime = StakeDetailsMapping[msg.sender][_index].startTime;
        
        require(stakeAmount > 0, "stake amount must be bigger than 0");
        require(block.timestamp >= stakeTime + 2 days, "min staking period is 2 days");

        uint reward = calculateYield(stakeAmount, stakeTime);
        //staking reset, rewards reset
        StakeDetailsMapping[msg.sender][_index].startTime = block.timestamp;
        tokenA.transfer(_to, reward);

        emit RewardClaimed(msg.sender, _index, reward);
    }

    //In case person would like to stake his reward, they can stake it here
    function stakeReward(uint _index) external onlyStakers {

        //fetching stake details for reward(yield) calculation
        uint stakeAmount = StakeDetailsMapping[msg.sender][_index].amount;
        uint stakeTime = StakeDetailsMapping[msg.sender][_index].startTime;
        require(stakeAmount > 0, "stake amount must be bigger than 0");
        require(block.timestamp >= stakeTime + 2 days, "min staking period is 2 days");
        uint reward = calculateYield(stakeAmount, stakeTime);

        //staking reset, rewards reset
        StakeDetailsMapping[msg.sender][_index].startTime = block.timestamp;
        //total stake amount of msg.sender increases with every new stake
        stakers[msg.sender] += reward;
        //Total staked amount in the system increases
        totalStaked += reward;

        //Creating a new stake record
        StakeDetails memory newStake = StakeDetails(reward, block.timestamp);
        //pushing new stake record to the stake array of the msg.sender
        StakeDetailsMapping[msg.sender].push(newStake);

        emit RewardStaked(msg.sender, _index, reward);
    }


    //Function lets everyone to stake anytime they want and as many times they want.
    //Each stake will be a new staking record.
    function stake(uint _amount) public {
        require(msg.sender != address(0), "Cannot stake from address 0");
        require(_amount > 0, "stake must be > 0");
        
        //assumption: user already approved contract. Now we can transfer tokens for staking.
        tokenA.transferFrom(msg.sender, address(this), _amount);

        //total stake amount of msg.sender increases with every new stake
        stakers[msg.sender] += _amount;

        StakeDetails memory newStake = StakeDetails(_amount, block.timestamp);

        StakeDetailsMapping[msg.sender].push(newStake);

        totalStaked += _amount;
    
        emit Staked(msg.sender, _amount);
    }

    //users can unstake their stakes. In this unstaking amount + accummulated reward will be
    //transferred to the msg.sender
    function unstake(address _to, uint _index) external onlyStakers {
        //input and general checks
        require(_to != address(0), "Cannot claim from address 0");
        require(msg.sender != address(0), "Cannot stake from address 0");

        //fetching stake details and calculating reward(yield)
        uint stakeAmount = StakeDetailsMapping[msg.sender][_index].amount;
        uint stakeTime = StakeDetailsMapping[msg.sender][_index].startTime;
        require(stakeAmount > 0, "stake amount must be bigger than 0");
        require(block.timestamp >= stakeTime + 2 days, "min staking period is 2 days");
        uint reward = calculateYield(stakeAmount, stakeTime);

        uint totalAmount = stakeAmount + reward;

        //staking reset, rewards reset
        StakeDetailsMapping[msg.sender][_index].amount = 0;
        StakeDetailsMapping[msg.sender][_index].startTime = block.timestamp;

        tokenA.transfer(_to, totalAmount);

        emit Unstaked(_to, _index);
    }











    function decreaseStake(address payable _to, uint _index, uint _amount) external {
        //1) To decrease stake, user must first claim the reward that is available (28 days condition).
        uint stakeTime = StakeDetailsMapping[msg.sender][_index].stakeDate;
        if(block.timestamp >= stakeTime + 28 seconds) { //DEPLOYMENT: 28 days
            revert("claim your reward first, then unstake");
        }

        // 2) transferring the desired stake amount (see ASSUMPTION 2)
        require(_amount < StakeDetailsMapping[msg.sender][_index].amount, "amount must be smaller than stake");
        StakeDetailsMapping[msg.sender][_index].amount -= _amount;
        // (bool success, ) = _to.call{value: _amount}(""); // UNCOMMENT IN DEPLOYMENT
        // require(success, "unstaking failed"); // UNCOMMENT IN DEPLOYMENT

        emit DecreasedStake(msg.sender, _index, _amount);
    }

    function displayStakes() external view returns(StakeDetails[] memory) {
        return StakeDetailsMapping[msg.sender];
    }
    function displaySpecificStake(uint _index) external view returns(StakeDetails memory) {
        return StakeDetailsMapping[msg.sender][_index];
    }
    function displaySpecificStakeAmount(uint _index) external view returns(uint) {
        return StakeDetailsMapping[msg.sender][_index].amount;
    }

    fallback() external payable{}
    receive() external payable{}

    /*
    function stake(uint _amount, uint _period, uint _apy) public { }
    function calculateReward(uint _index) internal onlyStakers { }
    function claimReward(uint _index) external onlyStakers { } reset blocktimestamp
    function stakeReward(uint _index) external onlyStakers { }
    function decreaseStake(uint _index) external onlyStakers {}
    function unstake(uint _index) external onlyStakers { }
    */

}