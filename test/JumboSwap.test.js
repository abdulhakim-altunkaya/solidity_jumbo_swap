const { expect } = require("chai");

describe("JumboSwap", () => {
  let contractJumboSwap;
  let contractTokenA;
  let contractTokenB;
  let owner;

  //I need these address later to send tokens between contract and accounts
  let addressJumboSwap;
  let addressTokenA;
  let addressTokenB;

  beforeEach(async () => {

    //JumboSwap Block
    const JumboSwap = await ethers.getContractFactory("JumboSwap");
    contractJumboSwap = await JumboSwap.deploy();
    await contractJumboSwap.deployed();
    //extra step for some functions
    addressJumboSwap = contractJumboSwap.address;
 
    //TokenA Block
    const TokenA = await ethers.getContractFactory("TokenA");
    contractTokenA = await TokenA.deploy(1000000); // Set the initial supply to 1000000
    await contractTokenA.deployed();

    //extra steps for some test blocks
    addressTokenA = contractTokenA.address;
    await contractTokenA.mintToken(20000);

    //TokenB Block
    const TokenB = await ethers.getContractFactory("TokenB");
    contractTokenB = await TokenB.deploy(1000000);
    await contractTokenB.deployed();

    //extra steps for some test blocks
    addressTokenB = contractTokenB.address;
    await contractTokenB.mintToken(20000);

    //getting owner for some test blocks
    [owner] = await ethers.getSigners();
  });

  it("Should deploy contract and print success message", async () => {
    console.log("Deployment is successful");
  });

  it("Should return the symbol of TokenA as TOKA", async () => {
    const tokenName = await contractTokenA.symbol();
    expect(tokenName).to.equal("TOKA");
  });

  it("Should return the owner of the TokenB", async () => {
    expect(await contractTokenB.owner()).to.equal(owner.address);
  });

  it("Should mint 1000 tokens from TokenA and TokenB and send it to msg.sender aka owner", async () => {
    const tokenBalance1 = await contractTokenA.getYourBalance();
    const tokenBalance2 = await contractTokenB.getYourBalance();
    //as it returns a string, I need to convert values to Number
    expect(Number(tokenBalance1) + Number(tokenBalance2)).to.equal(40000);
  });

  it("Should mint 2000 tokens from TokenA and TokenB and set token addresses on JumboSwap contract", async () => {
    await contractJumboSwap.setTokenAddresses(addressTokenA, addressTokenB);
    let tokenAddress = await contractJumboSwap.tokenA();
    console.log("here is the address of TokenA contract:", tokenAddress);
  });

  it("Should return the balance of owner address in TokenA", async () => {
    await contractJumboSwap.setTokenAddresses(addressTokenA, addressTokenB);
    const tokenABalance = await contractTokenA.balanceOf(owner.address);
    console.log("Owner Balance in TokenA is: ", tokenABalance);
  });

  it("Should add liquidity in JumboSwap contract", async () => {
    await contractJumboSwap.setTokenAddresses(addressTokenA, addressTokenB);
    // Approve the JumboSwap contract to receive the tokens
    await contractTokenA.approve(addressJumboSwap, ethers.utils.parseEther("2"));
    await contractTokenB.approve(addressJumboSwap, ethers.utils.parseEther("2"));
    // Add liquidity
    await contractJumboSwap.addLiquidity(2, 2);
    const tokenABalance = await contractTokenA.balanceOf(addressJumboSwap);
    expect(tokenABalance).to.equal(ethers.utils.parseEther("2"));
  })

  it("Should remove liquidity in JumboSwap contract", async () => {
    await contractJumboSwap.setTokenAddresses(addressTokenA, addressTokenB);
    // Approve the JumboSwap contract to receive the tokens
    await contractTokenA.approve(addressJumboSwap, ethers.utils.parseEther("2"));
    await contractTokenB.approve(addressJumboSwap, ethers.utils.parseEther("2"));
    // Add liquidity
    await contractJumboSwap.addLiquidity(2, 2);
    await contractJumboSwap.removeLiquidityTokenB(1);
    const tokenBBalance = await contractTokenB.balanceOf(addressJumboSwap);
    let expectedBalance = 1*(10**18); //instead of ethers.utils.parseEther("1")
    expect(tokenBBalance.toString()).to.equal(expectedBalance.toString()); //As number is very big, I need to convert it to string
  })

  it("Should swap 100 tokenA to tokenB", async () => {
    await contractJumboSwap.setTokenAddresses(addressTokenA, addressTokenB);
    // Approve the JumboSwap contract to receive the tokens
    await contractTokenA.approve(addressJumboSwap, ethers.utils.parseEther("1000"));
    await contractTokenB.approve(addressJumboSwap, ethers.utils.parseEther("600"));
    // Add liquidity
    await contractJumboSwap.addLiquidity(1000, 600);

    //grabbing tokenB balance of the JumboSwap contract for expect statement
    let tokenBBalance = await contractTokenB.balanceOf(addressJumboSwap);

    //approve JumboSwap contract to receive TokenA amount before swapping
    await contractTokenA.approve(addressJumboSwap, ethers.utils.parseEther("100"));
    //after approving TokenA amount, now we can swap it to TokenB amount.
    //100 is the amount of TokenA we want to swap and 5 is min TokenA amount.
    await contractJumboSwap.swapAwithB(100, 5);

    let expectedBalance = await contractTokenB.balanceOf(addressJumboSwap);
    expect(Number(expectedBalance)).to.be.lessThan(Number(tokenBBalance));
  });

  it("Should withdraw leftover tokens", async () => {
    await contractJumboSwap.setTokenAddresses(addressTokenA, addressTokenB);
    //approve JumboSwap contract to receive tokens
    await contractTokenA.approve(addressJumboSwap, ethers.utils.parseEther("500"));
    await contractTokenB.approve(addressJumboSwap, ethers.utils.parseEther("1000"));
    //add liquidity
    await contractJumboSwap.addLiquidity(500, 1000);

    //approve JumboSwap contract for receive TokenA amount from user before swapping
    await contractTokenB.approve(addressJumboSwap, ethers.utils.parseEther("300"));
    //after approving TokenA amount, now we can swap it to TokenB amount.
    //900 is the amount of TokenA we want to swap and 5 is min TokenA amount.
    await contractJumboSwap.swapBwithA(300, 5);

    //The use will get 150 tokenA for 300 tokenB. The contract will charge 0.15 tokenA for 
    //this operation. Which means If I call leftover function, it should succeed.
    const amountBamount = await contractJumboSwap.getTokenABalance();
    const reserveBamount = await contractJumboSwap.reserveA();
    //before withdrawal
    console.log("A general balance is:", amountBamount);
    console.log("A reserve Balance is:", reserveBamount);
    await contractJumboSwap.withdrawLeftoverTokens();
    const amountBamount2 = await contractJumboSwap.getTokenABalance();
    const reserveBamount2 = await contractJumboSwap.reserveA();
    //after withdrawal
    console.log("A general balance is:", amountBamount2);
    console.log("A reserve Balance is:", reserveBamount2);
    expect(amountBamount2.toString()).to.equal(reserveBamount2.toString());
  })
});

 