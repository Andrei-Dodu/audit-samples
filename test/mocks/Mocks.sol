// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory n, string memory s, uint8 d) {
        name = n;
        symbol = s;
        decimals = d;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @notice Constant-product pool, enough of the real thing to move a price.
contract MiniPair {
    address public immutable token0;
    address public immutable token1;
    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address t0, address t1) {
        token0 = t0;
        token1 = t1;
    }

    function sync() external {
        reserve0 = MockERC20(token0).balanceOf(address(this));
        reserve1 = MockERC20(token1).balanceOf(address(this));
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function swap(address tokenIn, uint256 amountIn) external returns (uint256 out) {
        bool zeroForOne = tokenIn == token0;
        (uint256 reserveIn, uint256 reserveOut) = zeroForOne ? (reserve0, reserve1) : (reserve1, reserve0);
        out = getAmountOut(amountIn, reserveIn, reserveOut);
        MockERC20(zeroForOne ? token1 : token0).transfer(msg.sender, out);
        this.sync();
    }
}

/// @notice Router the distributor talks to: routes TOKEN -> WETH through the pair.
contract MockRouter {
    MiniPair public immutable pair;
    address public immutable token;
    address public immutable weth;

    constructor(MiniPair pair_, address token_, address weth_) {
        pair = pair_;
        token = token_;
        weth = weth_;
        MockERC20(token_).approve(address(pair_), type(uint256).max);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length == 2 && path[0] == token && path[1] == weth, "path");
        require(block.timestamp <= deadline, "expired");
        MockERC20(token).transferFrom(msg.sender, address(pair), amountIn);
        uint256 out = pair.swap(token, amountIn);
        require(out >= amountOutMin, "too little received");
        MockERC20(weth).transfer(to, out);
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = out;
    }
}
