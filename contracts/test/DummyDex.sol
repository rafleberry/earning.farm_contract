pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../erc20/IERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../utils/SafeMath.sol";
import "../erc20/TokenInterface.sol";
import "../erc20/SafeERC20.sol";


contract DummyDex{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address[2] public token;
  constructor(address _t0, address _t1, uint256 _m0, uint256 _m1) public{
    token[0] = _t0;
    token[1] = _t1;
    TokenInterface(_t0).generateTokens(address(this), _m0);
    TokenInterface(_t1).generateTokens(address(this), _m1);
  }

  event Swap(uint256 In, uint256 Out, uint256 reserve0, uint256 reserve1);

  function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to) public returns (uint256 amounts) {
    address t0 = path[0];
    address t1 = path[path.length - 1];
    require(IERC20(t0).balanceOf(address(this)) > 0, "no liquidity");
    require(IERC20(t1).balanceOf(address(this)) > 0, "no liquidity");
    //emit SwapBefore(IERC20(token[0]).balanceOf(address(this)), IERC20(token[1]).balanceOf(address(this)));

    IERC20(t0).safeTransferFrom(msg.sender, address(this), amountIn);
    uint256 amountOut = amountIn*(IERC20(t1).balanceOf(address(this)))/(IERC20(t0).balanceOf(address(this)));
    IERC20(t1).safeTransfer(msg.sender, amountOut);
    emit Swap(amountIn, amountOut, IERC20(token[0]).balanceOf(address(this)), IERC20(token[1]).balanceOf(address(this)));
    return amountOut;
  }

  function exchange(uint256 i, uint256 j, uint256 amountIn, uint256 min_amount) public returns(uint256){
    uint256 j0 = j;
    if (j0 == 2) {j0 = 1;}
    address t0 = token[i];
    address t1 = token[j0];
    IERC20(t0).safeTransferFrom(msg.sender, address(this), amountIn);
    uint256 amountOut = amountIn * (IERC20(t1).balanceOf(address(this)))/(IERC20(t0).balanceOf(address(this)));
    IERC20(t1).safeTransfer(msg.sender, amountOut);
    emit Swap(amountIn, amountOut, IERC20(token[0]).balanceOf(address(this)), IERC20(token[1]).balanceOf(address(this)));
    return amountOut;
  }

}

contract DummyDexFactory{
  event NewDummyDex(address addr);

  function createDummyDex(address token0, address token1, uint256 t0, uint256 t1) public returns(address){
    DummyDex cf = new DummyDex(token0, token1, t0, t1);
    emit NewDummyDex(address(cf));
    return address(cf);
  }

}
