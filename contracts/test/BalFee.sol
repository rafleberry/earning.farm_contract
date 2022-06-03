pragma solidity >=0.4.21 <0.6.0;

import "../utils/SafeMath.sol";
import "../erc20/ERC20Impl.sol";

contract BalFee{
  uint256 fee;
  constructor() public {
    fee = 0;
  }
  function setFee(uint256 _fee) public{
    fee = _fee;
  }
  function getFlashLoanFeePercentage() external view returns (uint256){
    return fee;
  }
}
