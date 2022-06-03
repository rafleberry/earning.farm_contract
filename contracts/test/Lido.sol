pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../erc20/IERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../utils/SafeMath.sol";
import "../erc20/TokenInterface.sol";
import "../erc20/SafeERC20.sol";

contract Lido is IERC20, Ownable{
    using SafeMath for uint256;

    mapping (address => uint256) private shares;

    mapping (address => mapping (address => uint256)) private allowances;

    uint256 public totalLidoShares;
    uint256 public totalETH;

    address public pool;

    function changePool(address _pool) public onlyOwner{
        pool = _pool;
    }
    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return _getTotalPooledEther();
    }

    function getTotalPooledEther() public view returns (uint256) {
        return _getTotalPooledEther();
    }

    function balanceOf(address _account) public view returns (uint256) {
        return getPooledEthByShares(_sharesOf(_account));
    }
    event LidoSubmit(uint256 eth_amount, uint256 shares_amount);
    function submit(address _referral) external payable returns (uint256) {
        address sender = msg.sender;
        uint256 deposit = msg.value;
        require(deposit != 0, "ZERO_DEPOSIT");

        uint256 sharesAmount = getSharesByPooledEth(deposit);
        if (sharesAmount == 0) {
            // totalControlledEther is 0: either the first-ever deposit or complete slashing
            // assume that shares correspond to Ether 1-to-1
            sharesAmount = deposit;
        }

        _mintShares(sender, sharesAmount);
        pool.call.value(msg.value)("");
        totalETH = totalETH.safeAdd(deposit);
        emit LidoSubmit(deposit, sharesAmount);
        return sharesAmount;
    }

    function transfer(address _recipient, uint256 _amount) public returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) public returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public returns (bool) {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");

        _transfer(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, currentAllowance.safeSub(_amount));
        return true;
    }

    function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool) {
        _approve(msg.sender, _spender, allowances[msg.sender][_spender].safeAdd(_addedValue));
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "DECREASED_ALLOWANCE_BELOW_ZERO");
        _approve(msg.sender, _spender, currentAllowance.safeSub(_subtractedValue));
        return true;
    }

    function getTotalShares() public view returns (uint256) {
        return _getTotalShares();
    }

    function sharesOf(address _account) public view returns (uint256) {
        return _sharesOf(_account);
    }

    function getSharesByPooledEth(uint256 _ethAmount) public view returns (uint256) {
        uint256 totalPooledEther = _getTotalPooledEther();
        if (totalPooledEther == 0) {
            return 0;
        } else {
            return _ethAmount
                .safeMul(_getTotalShares())
                .safeDiv(totalPooledEther);
        }
    }

    function getPooledEthByShares(uint256 _sharesAmount) public view returns (uint256) {
        uint256 totalShares = _getTotalShares();
        if (totalShares == 0) {
            return 0;
        } else {
            return _sharesAmount
                .safeMul(_getTotalPooledEther())
                .safeDiv(totalShares);
        }
    }

    function _getTotalPooledEther() internal view returns (uint256){
      return totalETH;
    }

 
    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        uint256 _sharesToTransfer = getSharesByPooledEth(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _getTotalShares() internal view returns (uint256) {
        return totalLidoShares;
    }

    function _sharesOf(address _account) internal view returns (uint256) {
        return shares[_account];
    }

    function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");

        uint256 currentSenderShares = shares[_sender];
        require(_sharesAmount <= currentSenderShares, "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        shares[_sender] = currentSenderShares.safeSub(_sharesAmount);
        shares[_recipient] = shares[_recipient].safeAdd(_sharesAmount);
    }

    function _mintShares(address _recipient, uint256 _sharesAmount) internal returns (uint256) {
        require(_recipient != address(0), "MINT_TO_THE_ZERO_ADDRESS");

        totalLidoShares = _getTotalShares().safeAdd(_sharesAmount);

        shares[_recipient] = shares[_recipient].safeAdd(_sharesAmount);

    }

    function _burnShares(address _account, uint256 _sharesAmount) internal returns (uint256) {
        require(_account != address(0), "BURN_FROM_THE_ZERO_ADDRESS");

        uint256 accountShares = shares[_account];
        require(_sharesAmount <= accountShares, "BURN_AMOUNT_EXCEEDS_BALANCE");

        totalLidoShares = _getTotalShares().safeSub(_sharesAmount);

        shares[_account] = accountShares.safeSub(_sharesAmount);  

        return totalLidoShares;
    }
    function() external payable{
        pool.call.value(msg.value)("");
        totalETH = totalETH.safeAdd(msg.value);
    }
}
