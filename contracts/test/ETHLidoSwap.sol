pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../erc20/IERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../utils/SafeMath.sol";
import "../erc20/TokenInterface.sol";
import "../erc20/SafeERC20.sol";


contract ETHLidoSwap is Ownable{
  using SafeERC20 for IERC20;

  address public token;
  constructor(address _token) public{
    token = _token;
    //TokenInterface(_token).generateTokens(address(this), _amount);
  }

  event Swap(uint256 In, uint256 Out, uint256 reserve0, uint256 reserve1);

  function exchange(int128 i, int128 j, uint256 amountIn, uint256 min_amount) public payable returns(uint256){
    IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
    msg.sender.call.value(amountIn)("");
    return amountIn;
  }

  function claimETH(address payable _to) public onlyOwner{
    _to.call.value(address(this).balance)("");
  }
  

  function() external payable{}
}
