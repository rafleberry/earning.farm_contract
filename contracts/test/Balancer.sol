pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../erc20/IERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../utils/SafeMath.sol";
import "../erc20/TokenInterface.sol";
import "../erc20/SafeERC20.sol";
interface IFlashLoanRecipient{
  function receiveFlashLoan(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external;
}

interface IFee{
  function getFlashLoanFeePercentage() external view returns (uint256);
}


contract Balancer is Ownable{
  using SafeERC20 for IERC20;

  address fee_collect;

  constructor(address _addr) public{
    fee_collect = _addr;//18 decimal
  }

  function getFee() public view returns(uint256){
    return IFee(fee_collect).getFlashLoanFeePercentage();
  }

  event BalFlashLoan(address addr, uint256 amount, uint256 fee_amount);
  function flashLoan(
        address recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
  ) public{
    uint256 pre_bal = tokens[0].balanceOf(address(this));
    uint256[] memory feeAmounts = new uint256[](tokens.length);
    uint256 fee = getFee();
    feeAmounts[0] = amounts[0]*fee/1e18;
    tokens[0].safeTransfer(recipient, amounts[0]);
    IFlashLoanRecipient(recipient).receiveFlashLoan(tokens, amounts, feeAmounts, userData);
    uint256 post_bal = tokens[0].balanceOf(address(this));
    require(pre_bal + feeAmounts[0] <= post_bal, "INSUFFICIENT_FLASH_LOAN_FEE_AMOUNT");
    emit BalFlashLoan(recipient, amounts[0], feeAmounts[0]);
  }

  function claimETH(address payable _to) public onlyOwner{
    _to.call.value(address(this).balance)("");
  }
  function claimStdERC20(address token, address _to) public onlyOwner{
    IERC20(token).transfer(_to, IERC20(token).balanceOf(address(this)));
  }

  function() external payable{}
}

