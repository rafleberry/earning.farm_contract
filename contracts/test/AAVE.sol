pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../erc20/IERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../utils/SafeMath.sol";
import "../erc20/TokenInterface.sol";
import "../erc20/SafeERC20.sol";


contract AAVE is Ownable{
  //using SafeMath for uint256;
  using SafeERC20 for IERC20;

  mapping (address => uint256) public debts;
  uint256 public index;
  address public aToken;
  address public weth;
  constructor(address _token) public{
      aToken = _token;
      index = 1e18;
  }
  function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external{
    IERC20(asset).safeTransfer(onBehalfOf, amount);
    uint256 deb = amount * 1e18 / index;
    debts[msg.sender] += deb;
  }
  function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external{
    IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    TokenInterface(aToken).generateTokens(onBehalfOf, amount);
  }
  function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256){
    TokenInterface(aToken).destroyTokens(msg.sender, amount);
    IERC20(asset).safeTransfer(to, amount);
  }
  function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256){
    IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    uint256 deb = amount * 1e18 / index;
  
    require(debts[msg.sender] >= deb, "aave: repay too much");
    debts[msg.sender] -= deb;
  }

  function changeDebtIndex(uint256 _index) public{
    index = _index;
  }
  function getUserAccountData(address account)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ){
    totalCollateralETH = IERC20(aToken).balanceOf(account);
    totalDebtETH = debts[account] * index / 1e18;
    availableBorrowsETH = 0;
    currentLiquidationThreshold = 0;
    ltv = 0;
    healthFactor = 0;
  }
  function claimStdERC20(address token, address _to) public onlyOwner{
    IERC20(token).transfer(_to, IERC20(token).balanceOf(address(this)));
  }
}

