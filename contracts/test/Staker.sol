pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../erc20/IERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../utils/SafeMath.sol";
import "../erc20/TokenInterface.sol";
import "../erc20/SafeERC20.sol";


contract Staker{
  address[] public token;
  address public lp;
  mapping (address => uint256) public balance; 
  mapping (address => uint256) public last_block; 
  mapping (address => uint256) public reward; 

  constructor(address _lp, address _t0, address _t1) public{
    lp = _lp;
    token.push(_t0);
    token.push(_t1);
  }

  function _check_point(address addr) internal{
    if (last_block[addr] == 0) {last_block[addr] = block.number;}
    reward[addr] += (block.number - last_block[addr]) * balance[addr];
  }

  function add_token(address _t) public{
    token.push(_t);
  }

  function stake(uint256 amount) public returns(bool){
    IERC20(lp).transferFrom(msg.sender, address(this), amount);
    _check_point(msg.sender);
    balance[msg.sender] += amount;
    return true;
  }

  function withdraw(uint256 amount, bool claim) public returns(bool){
    require(amount <= balance[msg.sender], "Staker: not enough balance");
    _check_point(msg.sender);
    balance[msg.sender] -= amount;
    IERC20(lp).transfer(msg.sender, amount);
    if (claim){
      getReward();
    }
    return true;
  }

  function getReward() public returns(bool){
    _check_point(msg.sender);
    for (uint i = 0; i < token.length; i++){
      TokenInterface(token[i]).generateTokens(msg.sender, reward[msg.sender]/10000);
    }
    reward[msg.sender] = 0;
    return true;
  }
}

contract StakerFactory{
  event NewStaker(address addr);
  function createStaker(address lp, address token0, address token1) public returns(address){
    Staker cf = new Staker(lp, token0, token1);
    emit NewStaker(address(cf));
    return address(cf);
  }

}
