// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title JumboSwap - An Automated Market Maker for TokenA and TokenB
 * @author Abdulhakim Altunkaya
 * @notice This contract manages a liquidity pool and supports token swaps.
 * @dev This contract is prepared for the Patika Hackathon, August 2023.
 */
contract JumboSwap is Ownable {

    // Events to log important contract activities
    event SwapHappened(address tokenIn, uint amountIn, address tokenOut, uint amountOut, address client);
    event PoolIncreased(string message, uint amountA, uint amountB, uint reserveA, uint reserveB);
    event PoolDecreased(string message, uint amountA, uint amountB, uint reserveA, uint reserveB);
    event FeeUpdated(uint newFee);

    // ---- STATE VARIABLES ----
    //Token addresses and reserves
    address public tokenA;
    address public tokenB;
    address public contractAddress;
    uint public reserveA;
    uint public reserveB;
    //liquidity provision variables
    struct LPdetails {
        bool status;
        uint amountADeposit;
        uint amountBDeposit;

    }
    mapping(address => LPdetails) public liquidityProviders;

    // SECURITY CHECK 1: Emergency pause mechanism, onlyOwner can call
    bool internal pauseStatus = false;
    function pauseEverything() external onlyOwner {
        pauseStatus = !pauseStatus;
    }
    error Paused(string message, address caller);
    modifier isPaused() {
        if (pauseStatus == true) {
            revert Paused("Contract is paused for security concerns, contact owner", owner());
        }
        _;
    }

    // SECURITY CHECK 2: Ensure valid ERC20 token addresses before setting
    function isERC20Token(address _tokenAddress) internal view returns(bool) {
        try IERC20(_tokenAddress).totalSupply() returns(uint) {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @notice Set token addresses for TokenA and TokenB
     * @dev Only the contract owner can set the token addresses
     * @param _tokenA Address of TokenA
     * @param _tokenB Address of TokenB
     */
    function setTokenAddresses(address _tokenA, address _tokenB) external onlyOwner {
        require(isERC20Token(_tokenA) == true, "not valid tokenA address");
        require(isERC20Token(_tokenB) == true, "not valid tokenB address");
        tokenA = _tokenA;
        tokenB = _tokenB;
        contractAddress = address(this);
    }

    // Fee structure. Further calculation will be handled inside swap functions.
    uint public feePercentage = 1; // Fee percentage (default 1 means 0.1% fee)
    /**
     * @notice Update the transaction fee percentage
     * @dev Only the contract owner can update the fee percentage
     * @param _fee New fee percentage to be set
     */
    function updateFeePercentage(uint _fee) external isPaused onlyOwner {
        require(_fee < 30, "fee cannot be bigger than %3");
        feePercentage = _fee;
        emit FeeUpdated(feePercentage);
    } 

    /**
     * @notice Add liquidity to the contract's pool
     * @dev Anyone can add liquidity, but the contract must be unpaused
     * @param _amountA Amount of TokenA to be added
     * @param _amountB Amount of TokenB to be added
     */
    function addLiquidity(uint _amountA, uint _amountB) external isPaused {
        require(_amountA > 0 && _amountB > 0, "amounts of tokenA and tokenB must be greater than 0");

        // Convert amounts to match token decimals
        uint amountA = _amountA * (10**18);
        uint amountB = _amountB * (10**18);
      
        // Transfer tokens from sender to the contract (pool)
        IERC20(tokenA).transferFrom(owner(), contractAddress, amountA);
        IERC20(tokenB).transferFrom(owner(), contractAddress, amountB);

        reserveA += amountA;
        reserveB += amountB;

        //liquidityProviders mapping updates
        liquidityProviders[msg.sender].amountADeposit += amountA;
        liquidityProviders[msg.sender].amountBDeposit += amountB;
        liquidityProviders[msg.sender].status = true;

        emit PoolIncreased("PLUS", amountA, amountB, reserveA, reserveB);
    }

    /**
     * @notice Remove liquidity of TokenA from the contract's pool
     * @dev Only the contract owner can remove liquidity in a proportional way
     * @param _amountA Amount of TokenA to be removed
     */
    function removeLiquidityTokenA(uint _amountA) external isPaused onlyOwner {
        require(_amountA > 0, "removal amount must be bigger than 0");

        // Convert amount to match token decimals
        uint amountA = _amountA * (10**18);

        // Calculate the proportional amount of TokenB to maintain balance
        uint amountB = (amountA * reserveB) / reserveA;

        // Update reserves
        reserveA -= amountA;
        reserveB -= amountB;

        // Transfer tokens back to the owner
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit PoolDecreased("MINUS", amountA, amountB, reserveA, reserveB);
    }

    /**
     * @notice Remove liquidity of TokenB from the contract's pool
     * @dev Only the contract owner can remove liquidity in a proportional way
     * @param _amountB Amount of TokenB to be removed
     */
    function removeLiquidityTokenB(uint _amountB) external isPaused onlyOwner {
        require(_amountB > 0, "removal amount must be bigger than 0");

        // Convert amount to match token decimals
        uint amountB = _amountB * (10**18);

        // Calculate the proportional amount of TokenA to maintain balance
        uint amountA = (amountB * reserveA) / reserveB;

        // Update reserves
        reserveA -= amountA;
        reserveB -= amountB;

        // Transfer tokens back to the owner
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit PoolDecreased("MINUS", amountA, amountB, reserveA, reserveB);
    }

    /**
     * @notice Swap TokenA for TokenB
     * @dev Users can swap TokenA for TokenB, charging a fee based on feePercentage
     * @param amountIn Amount of TokenA to be swapped
     * @param amountOutMin Minimum amount of TokenB expected from the swap
     */
    function swapAwithB(uint amountIn, uint amountOutMin) external isPaused {
        require(amountIn > 0, "Amount must be greater than 0");

        // Convert input amounts to match token decimals
        uint amountInDecimalsAdded = amountIn * (10**18);
        uint amountOutMinDecimalsAdded = amountOutMin * (10**18);

        // Ensure swap amounts are reasonable compared to pool size
        require(amountInDecimalsAdded < reserveA / 2, "swap amounts should not be as big as pool");

        // Calculate the amount of TokenB to receive based on pool ratio
        uint amountOut = (amountInDecimalsAdded * reserveB) / reserveA;

        // Update reserves before calculating fee
        reserveA += amountInDecimalsAdded;
        reserveB -= amountOut;

        // Calculate fee based on mathematical proportion
        uint txFee = (amountOut * feePercentage) / 1000;
        // Deduct fee from amountOut
        amountOut -= txFee;

        // Ensure the output amount meets the minimum required
        require(amountOut >= amountOutMinDecimalsAdded, "actual output is smaller than the desired output");

        // Transfer TokenA from the sender to the contract
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountInDecimalsAdded);

        // Transfer TokenB from the contract to the sender
        IERC20(tokenB).transfer(msg.sender, amountOut);

        emit SwapHappened(tokenA, amountInDecimalsAdded, tokenB, amountOut, msg.sender);
    }

    /**
     * @notice Swap TokenB for TokenA
     * @dev Users can swap TokenB for TokenA, charging a fee based on feePercentage
     * @param amountIn Amount of TokenB to be swapped
     * @param amountOutMin Minimum amount of TokenA expected from the swap
     */
    function swapBwithA(uint amountIn, uint amountOutMin) external isPaused {
        require(amountIn > 0, "Amount must be greater than 0");

        // Convert input amounts to match token decimals
        uint amountInDecimalsAdded = amountIn * (10**18);
        uint amountOutMinDecimalsAdded = amountOutMin * (10**18);

        // Ensure swap amounts are reasonable compared to pool size
        require(amountInDecimalsAdded < reserveB / 2, "swap amounts should not be as big as pool");

        // Calculate the amount of TokenA to receive based on pool ratio
        uint amountOut = (amountInDecimalsAdded * reserveA) / reserveB;

        // Update reserves before calculating fee
        reserveB += amountInDecimalsAdded;
        reserveA -= amountOut;

        // Calculate fee based on mathematical proportion
        uint txFee = (amountOut * feePercentage) / 1000;
        // Deduct fee from amountOut
        amountOut -= txFee;

        // Ensure the output amount meets the minimum required
        require(amountOut >= amountOutMinDecimalsAdded, "actual output is smaller than the desired output");

        // Transfer TokenB from the sender to the contract
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountInDecimalsAdded);

        // Transfer TokenA from the contract to the sender
        IERC20(tokenA).transfer(msg.sender, amountOut);

        emit SwapHappened(tokenB, amountInDecimalsAdded, tokenA, amountOut, msg.sender);
    }

    /**
     * @notice Withdraw leftover tokens from the contract
     * @dev Only the contract owner can withdraw tokens not part of the liquidity pool
     */
    function withdrawLeftoverTokens() external isPaused onlyOwner {
        // Calculate the contract's token balances
        uint amountTokenA = IERC20(tokenA).balanceOf(address(this));
        uint amountTokenB = IERC20(tokenB).balanceOf(address(this));

        // Calculate leftover tokens
        uint leftoverTokenA = amountTokenA - reserveA;
        uint leftoverTokenB = amountTokenB - reserveB;

        // Ensure leftovers are above 1 token
        require(leftoverTokenA >= 0 || leftoverTokenB >= 0, "leftover token must be bigger than 0");

        // Transfer leftovers from the contract to the owner
        IERC20(tokenA).transfer(msg.sender, leftoverTokenA);
        IERC20(tokenB).transfer(msg.sender, leftoverTokenB);
    }

    /**
     * @notice Get the reserves of TokenA and TokenB in the contract
     * @dev This function is used by the frontend to display reserve status without decimals
     * @return Reserve amounts of TokenA and TokenB
     */
    function getReserves() external view returns(uint, uint) {
        uint reserveAnew = reserveA / (10**18);
        uint reserveBnew = reserveB / (10**18);
        return (reserveAnew, reserveBnew);
    }

    /**
     * @notice Get the current balance of TokenA and TokenB in the contract
     * @dev This function is used by the frontend to display contract balances without decimals
     * @return Balance amounts of TokenA and TokenB
     */
    function getContactBalance() external view returns(uint, uint) {
        uint amountTokenA = IERC20(tokenA).balanceOf(address(this)) / (10**18);
        uint amountTokenB = IERC20(tokenB).balanceOf(address(this)) / (10**18);
        return (amountTokenA, amountTokenB);
    }

    /**
     * @notice Get the balance of TokenA in the contract
     * @dev This function is used by the frontend to display the balance of TokenA in the contract
     * @return Balance amount of TokenA in the contract
     */
    function getTokenABalance() external view returns(uint) {
        uint amountTokenA = IERC20(tokenA).balanceOf(address(this));
        return amountTokenA;
    }

    /**
     * @notice Get the balance of TokenB in the contract
     * @dev This function is used by the frontend to display the balance of TokenB in the contract
     * @return Balance amount of TokenB in the contract
     */
    function getTokenBBalance() external view returns(uint) {
        uint amountTokenB = IERC20(tokenB).balanceOf(address(this));
        return amountTokenB;
    }


}
