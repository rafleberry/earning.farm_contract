pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../erc20/IERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../utils/SafeMath.sol";
import "../erc20/TokenInterface.sol";
import "../erc20/SafeERC20.sol";


contract DummyDex2{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address[2] public token;
  constructor(address _t0, address _t1, uint256 _m0, uint256 _m1) public{
    token[0] = _t0;
    token[1] = _t1;
    TokenInterface(_t0).generateTokens(address(this), _m0);
    TokenInterface(_t1).generateTokens(address(this), _m1);
  }

  event Swap2(uint256 In, uint256 Out);

  function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to) public returns (uint256 amounts) {
    address t0 = path[0];
    address t1 = path[path.length - 1];
    require(IERC20(t0).balanceOf(address(this)) > 0, "no liquidity");
    require(IERC20(t1).balanceOf(address(this)) > 0, "no liquidity");
    IERC20(t0).safeTransferFrom(msg.sender, address(this), amountIn);
    uint256 amountOut = amountIn*(IERC20(t1).balanceOf(address(this)))/(IERC20(t0).balanceOf(address(this)));
    IERC20(t1).safeTransfer(msg.sender, amountOut);
    emit Swap2(amountIn, amountOut);
    return amountOut;
  }

  function exchange(int128 i, int128 j, uint256 amountIn, uint256 min_amount) public returns(uint256){
    address t0 = token[uint256(i)];
    address t1 = token[uint256(j)];
    IERC20(t0).safeTransferFrom(msg.sender, address(this), amountIn);
    uint256 amountOut = amountIn * (IERC20(t1).balanceOf(address(this)))/(IERC20(t0).balanceOf(address(this)));
    IERC20(t1).safeTransfer(msg.sender, amountOut);
    emit Swap2(amountIn, amountOut);
    return amountOut;
  }

  function get_dy(int128 i, int128 j, uint256 dx) external view returns(uint256){
    uint256 j0 = uint256(j);
    if (j0 == 2) {j0 = 1;}
    address t0 = token[uint256(i)];
    address t1 = token[uint256(j0)];
    uint256 amountOut = dx * (IERC20(t1).balanceOf(address(this)))/(IERC20(t0).balanceOf(address(this)) + dx);
    return amountOut;
  }
}

contract DummyDex2Factory{
  event NewDummyDex2(address addr);

  function createDummyDex2(address token0, address token1, uint256 m0, uint256 m1) public returns(address){
    DummyDex2 cf = new DummyDex2(token0, token1, m0, m1);
    emit NewDummyDex2(address(cf));
    return address(cf);
  }

}
