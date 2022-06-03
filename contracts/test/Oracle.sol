pragma solidity >=0.4.21 <0.6.0;

import "../utils/SafeMath.sol";
import "../erc20/ERC20Impl.sol";

contract Oracle{

  constructor() public {
  }

  function latestAnswer() external view returns (int256){
    return 200000000;
  }
}
