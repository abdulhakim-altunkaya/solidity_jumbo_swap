// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract is Ownable {
    struct Stake {
        uint256 amount;
        uint256 startTime;
    }

    mapping(address => Stake) public stakes;

    address public tokenA;
    address public tokenB;

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    event Staked(address indexed user, uint256 amount, address indexed token);
    event Withdrawn(address indexed user, uint256 amount, address indexed token);

    modifier hasStake() {
        require(stakes[msg.sender].amount > 0, "No stake available");
        _;
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
