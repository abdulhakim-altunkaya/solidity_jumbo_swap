// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

    //JumboSwap is an Automated Market Maker. It manages
    //a pool of TokenA and TokenB. The project is prepared for Patika Hackathon.
    //by Abdulhakim Altunkaya, August 2023

contract JumboSwap is Ownable {

    //events
    event SwapHappened(address tokenIn, uint amountIn, address tokenOut, uint amountOut, address client);
    event PoolIncreased(string message, uint amountA, uint amountB, uint reserveA, uint reserveB);
    event PoolDecreased(string message, uint amountA, uint amountB, uint reserveA, uint reserveB);
    event FeeUpdated(uint newFee);

    //Main state variables: Token addresses and reserves
    address public tokenA;
    address public tokenB;
    address public contractAddress;
    uint public reserveA;
    uint public reserveB;

    //SECURITY CHECK 1: pausing functions in case of emergencies, onlyOwner can call
    bool internal pauseStatus = false;
    function pauseEverything() external onlyOwner {
        pauseStatus = !pauseStatus;
    }
    error Paused(string message, address caller);
    modifier isPaused() {
        if(pauseStatus == true) {
            revert Paused("Contract is paused for security concerns, contact owner", owner());
        }
        _;
    }

    //SECURITY CHECK 2: Before setting addresses for our token contract variables, we
    //need to check if the addresses belong to ERC20 tokens. They need to return a number
    //if we call totalSupply() erc20 method on them.
    function isERC20Token(address _tokenAddress) internal view returns(bool) {
        try IERC20(_tokenAddress).totalSupply() returns(uint) {
            return true;
        } catch {
            return false;
        }
    }

    //Token contract variables are assigned to their contract addresses here. Owner of the project
    //will handle this funciton on the frontend.
    function setTokenAddresses(address _tokenA, address _tokenB) external onlyOwner {
        require(isERC20Token(_tokenA) == true, "not valid tokenA address");
        require(isERC20Token(_tokenB) == true, "not valid tokenB address");
        tokenA = _tokenA;
        tokenB = _tokenB;
        contractAddress = address(this);
    }

    // Fee structure. Further calculation will be handled inside swap functions.
    uint public feePercentage = 1; // Fee percentage (default 1 means 0.1% fee)
    function updateFeePercentage(uint _fee) external isPaused onlyOwner {
        require(_fee < 30, "fee cannot be bigger than %3");
        feePercentage = _fee;
        emit FeeUpdated(feePercentage);
    } 

    //anybody can tokenA and tokenB liquidity to the contract.
    function addLiquidity(uint _amountA, uint _amountB) external isPaused {
        require(_amountA > 0 && _amountB > 0, "amounts of tokenA and tokenB must be greater than 0");

        //adding decimals
        uint amountA = _amountA * (10**18);
        uint amountB = _amountB * (10**18);
      
        //transfer tokens from sender to the contract(pool)
        IERC20(tokenA).transferFrom(owner(), contractAddress, amountA);
        IERC20(tokenB).transferFrom(owner(), contractAddress, amountB);

        reserveA += amountA;
        reserveB += amountB;

        emit PoolIncreased("PLUS", amountA, amountB, reserveA, reserveB);
    }

    //onlyOwner can remove liquidty from contract. This will be done in a proportional way.
    //that's why there are two different removeliquidity functions
   function removeLiquidityTokenA(uint _amountA) external isPaused onlyOwner {
        require(_amountA > 0, "removal amount must be bigger than 0");

        //adding decimals
        uint amountA = _amountA * (10**18);

        //we need to withdraw a proportional amount from tokenB also to keep the balance of the pool
        //To do so, we use a basic mathematical proportion.
        uint amountB = (amountA * reserveB) / reserveA;

        //decrease the reserves
        reserveA -= amountA;
        reserveB -= amountB;

        //transfer tokens back to msg.sender who is owner
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit PoolDecreased("MINUS", amountA, amountB, reserveA, reserveB);
    }

    function removeLiquidityTokenB(uint _amountB) external isPaused onlyOwner {
        require(_amountB > 0, "removal amount must be bigger than 0");

        //adding 18 decimals
        uint amountB = _amountB * (10**18);

        //calculate corresponding amount as above
        uint amountA = (amountB * reserveA) / reserveB;

        //decrease the reserves
        reserveA -= amountA;
        reserveB -= amountB;

        //transfer tokens to the msg.sender
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit PoolDecreased("MINUS", amountA, amountB, reserveA, reserveB);
    }


    //This view function will be used by Frontend. It will show reserve status without decimals
    function getReserves() external view returns(uint, uint) {
        uint reserveAnew = reserveA / (10**18);
        uint reserveBnew = reserveB / (10**18);
        return (reserveAnew, reserveBnew);
    }
}
