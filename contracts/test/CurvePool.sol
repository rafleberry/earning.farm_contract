pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../erc20/IERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../utils/SafeMath.sol";
import "../erc20/TokenInterface.sol";
import "../erc20/SafeERC20.sol";


contract CurvePool{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public lp_token;
  address public token;
  constructor(address _lp, address _token) public{
    lp_token = _lp;
    token = _token;
  }
  function remove_liquidity_one_coin(uint256 _token_amount, uint128 i, uint256 min_amount) external{
    TokenInterface(lp_token).destroyTokens(msg.sender, _token_amount);
    TokenInterface(token).generateTokens(msg.sender, _token_amount/1e12);
  }

}
