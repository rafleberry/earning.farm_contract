pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../utils/SafeMath.sol";
import "../utils/Address.sol";
import "../utils/ReentrancyGuard.sol";
import "../erc20/SafeERC20.sol";
import "./Interfaces.sol";

contract TokenInterfaceERC20{
  function destroyTokens(address _owner, uint _amount) public returns(bool);
  function generateTokens(address _owner, uint _amount) public returns(bool);
}

contract EFCRVVault is Ownable, ReentrancyGuard{
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  using Address for address;

  address public crv;
  address public usdc;

  uint256 public ratio_base;
  uint256 public slippage;
  uint256 public withdraw_fee_ratio;
  uint256 public harvest_fee_ratio;
  address payable public fee_pool;
  address public ef_token;
  uint256 public lp_balance;//cvxcrv balance
  uint256 public deposit_target_amount;//CRV
  uint256 public last_earn_block;


  address public eth_usdc_router;
  address public weth;
  address public cvxcrv;
  address public eth_crv_router;
  address public crv_cvxcrv_router;
  address public eth_usdt_router;//0 usdt, 1wbtc, 2weth
  address public staker;
  address public usdt;
  address public oracle;//our price is 18 dec
  address public oracle_eth;

  address[] public extra_yield_tokens;

  mapping(address => uint256) reward_types;//0:origin, 1:cvx, 2:3crv
  mapping(address => address) swaper;

  bool is_paused;

  //@param _crv, means ETH if it's 0x0
  constructor(address _ef_token) public {
    crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    usdc =  address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ratio_base = 10000;
    ef_token = _ef_token;
    eth_usdc_router =  address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    weth =  address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    cvxcrv =  address(0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7);
    eth_crv_router =  address(0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511);
    crv_cvxcrv_router =  address(0x9D0464996170c6B9e75eED71c68B99dDEDf279e8);//curve128
    eth_usdt_router =  address(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    usdt =  address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    oracle =  address(0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f);
    staker = address(0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e);
    oracle_eth = address(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4);//usdc to eth, 18 dec
  }

  event CFFDeposit(address from, uint256 target_amount, uint256 stable_amount, uint256 cff_amount, uint256 virtual_price);
  event CFFDepositFee(address from, uint256 target_amount, uint256 fee_amount);

  function deposit(uint256 _amount) public payable nonReentrant{
    require(!is_paused, "paused");

    require(IERC20(crv).allowance(msg.sender, address(this)) >= _amount, "CFVault: not enough allowance");

    require(_amount != 0, "too small amount");

    uint tt_before = IERC20(crv).balanceOf(address(this));
    IERC20(crv).safeTransferFrom(msg.sender, address(this), _amount);

    uint tt_after = IERC20(crv).balanceOf(address(this));
    require(tt_after.safeSub(tt_before) == _amount, "token inflation");

    _deposit(_amount.safeMul(uint256(ChainlinkInterface(oracle).latestAnswer())).safeDiv(1e20), _amount);//Todo
  }
  function depositStable(uint256 _amount) public payable nonReentrant{
    require(!is_paused, "paused");

    require(IERC20(usdc).allowance(msg.sender, address(this)) >= _amount, "CFVault: not enough allowance");
    IERC20(usdc).safeTransferFrom(msg.sender, address(this), _amount);

    if (IERC20(usdc).allowance(address(this), eth_usdc_router) != 0){
      IERC20(usdc).approve(eth_usdc_router, 0);
    }
    IERC20(usdc).approve(eth_usdc_router, _amount);

    uint256 weth_before = IERC20(weth).balanceOf(address(this));
    {
      address[] memory t = new address[](2);
      t[0] = usdc;
      t[1] = weth;
      uint256 min_amount = _amount.safeMul(uint256(ChainlinkInterface(oracle_eth).latestAnswer())).safeMul(slippage).safeDiv(1e10);//-6-4
      UniswapV3Interface(eth_usdc_router).swapExactTokensForTokens(_amount, min_amount, t, address(this));
    }
    uint256 weth_amount = IERC20(weth).balanceOf(address(this)).safeSub(weth_before);
    if (IERC20(weth).allowance(address(this), eth_crv_router) != 0){
      IERC20(weth).approve(eth_crv_router, 0);
    }
    IERC20(weth).approve(eth_crv_router, weth_amount);

    uint256 tt_before = IERC20(crv).balanceOf(address(this));
    CurveInterface256(eth_crv_router).exchange(0, 1, weth_amount, 0);
    uint256 tt_amount = IERC20(crv).balanceOf(address(this)).safeSub(tt_before);

    _deposit(_amount, tt_amount);
  }

  function _deposit(uint256 _stable_amount, uint256 _amount) internal{
    uint256 lp_before = lp_balance;
    uint256 lp_amount = _stake(_amount);

    uint256 d = 18;
    uint cff_amount = 0;
    if (lp_before == 0){
      cff_amount = lp_amount.safeMul(uint256(10)**18).safeDiv(uint256(10)**d);
    }
    else{
      cff_amount = lp_amount.safeMul(IERC20(ef_token).totalSupply()).safeDiv(lp_before);
    }
    TokenInterfaceERC20(ef_token).generateTokens(msg.sender, cff_amount);
    emit CFFDeposit(msg.sender, _amount, _stable_amount, cff_amount, getVirtualPrice());
  }

  function _stake(uint256 _amount) internal returns(uint256){
    uint256 lp_before = IERC20(cvxcrv).balanceOf(address(this));
    deposit_target_amount = deposit_target_amount.safeAdd(_amount);
    if (IERC20(crv).allowance(address(this), crv_cvxcrv_router) != 0){
      IERC20(crv).approve(crv_cvxcrv_router, 0);
    }
    IERC20(crv).approve(crv_cvxcrv_router, _amount);

    CurveInterface128(crv_cvxcrv_router).exchange(0, 1, _amount, 0);
    uint256 lp_amount = IERC20(cvxcrv).balanceOf(address(this)).safeSub(lp_before);

    lp_balance = lp_balance.safeAdd(IERC20(cvxcrv).balanceOf(address(this)));

    if (IERC20(cvxcrv).allowance(address(this), staker) != 0){
      IERC20(cvxcrv).approve(staker, 0);
    }
    IERC20(cvxcrv).approve(staker, IERC20(cvxcrv).balanceOf(address(this)));

    ConvexInterface(staker).stake(IERC20(cvxcrv).balanceOf(address(this)));
    return lp_amount;
  }

  event CFFWithdraw(address from, uint256 target_amount, uint256 stable_amount, uint256 cff_amount, uint256 target_fee, uint256 virtual_price);
  //@_amount: CFLPToken amount
  function withdraw(uint256 _amount, bool _use_stable) public nonReentrant{
    require(!is_paused, "paused");

    {
      uint256 total_balance = IERC20(ef_token).balanceOf(msg.sender);
      require(total_balance >= _amount, "not enough LP tokens");
    }
    uint256 target_amount;
    {
      uint256 lp_amount = _amount.safeMul(lp_balance).safeDiv(IERC20(ef_token).totalSupply());

      uint256 target_before = IERC20(crv).balanceOf(address(this));
      _withdraw(lp_amount);

      target_amount = IERC20(crv).balanceOf(address(this)).safeSub(target_before);
    }
    uint256 f = 0;
    if(withdraw_fee_ratio != 0 && fee_pool != address(0x0)){
      f = target_amount.safeMul(withdraw_fee_ratio).safeDiv(ratio_base);
      target_amount = target_amount.safeSub(f);
      IERC20(crv).transfer(fee_pool, f);
      TokenInterfaceERC20(ef_token).destroyTokens(msg.sender, _amount);
    }else{
      TokenInterfaceERC20(ef_token).destroyTokens(msg.sender, _amount);
    }
    if (!_use_stable){
      IERC20(crv).transfer(msg.sender, target_amount);
      emit CFFWithdraw(msg.sender, target_amount, target_amount.safeMul(uint256(ChainlinkInterface(oracle).latestAnswer())).safeDiv(1e20), _amount, f, getVirtualPrice());
    }
    else{
      if (IERC20(crv).allowance(address(this), eth_crv_router) != 0){
        IERC20(crv).approve(eth_crv_router, 0);
      }
      IERC20(crv).approve(eth_crv_router, target_amount);

      uint256 weth_amount;
      {
        uint256 weth_before = IERC20(weth).balanceOf(address(this));
        CurveInterface256(eth_crv_router).exchange(1, 0, target_amount, 0);
        weth_amount = IERC20(weth).balanceOf(address(this)).safeSub(weth_before);
      }

      if (IERC20(weth).allowance(address(this), eth_usdc_router) != 0){
        IERC20(weth).approve(eth_usdc_router, 0);
      }
      IERC20(weth).approve(eth_usdc_router, weth_amount);

      uint256 usdc_amount;
      {
        address[] memory t = new address[](2);
        t[0] = weth;
        t[1] = usdc;
        uint256 usdc_before = IERC20(usdc).balanceOf(address(this));
        uint256 min_amount = weth_amount.safeMul(slippage).safeMul(1e2).safeDiv(uint256(ChainlinkInterface(oracle_eth).latestAnswer()));//6-4
        UniswapV3Interface(eth_usdc_router).swapExactTokensForTokens(weth_amount, min_amount, t, address(this));
        usdc_amount = IERC20(usdc).balanceOf(address(this)).safeSub(usdc_before);
      }
      IERC20(usdc).transfer(msg.sender, usdc_amount);
      emit CFFWithdraw(msg.sender, target_amount, usdc_amount, _amount, f, getVirtualPrice());
    }
  }

  function _withdraw(uint256 _amount) internal{
    ConvexInterface(staker).withdraw(_amount, false);
    lp_balance = lp_balance.safeSub(_amount);

    if (IERC20(cvxcrv).allowance(address(this), crv_cvxcrv_router)!= 0){
      IERC20(cvxcrv).approve(crv_cvxcrv_router, 0);
    }
    IERC20(cvxcrv).approve(crv_cvxcrv_router, _amount);

    CurveInterface128(crv_cvxcrv_router).exchange(1, 0, _amount, 0);
  }

  event EFRefundCRV(uint256 amount, uint256 fee);
  function earnReward() public onlyOwner{
    require(!is_paused, "paused");

    last_earn_block = block.number;

    ConvexInterface(staker).getReward();

    for(uint i = 0; i < extra_yield_tokens.length; i++){
      uint256 extra_amount = IERC20(extra_yield_tokens[i]).balanceOf(address(this));
      if(extra_amount > 0){
        _handleExtraToken(extra_yield_tokens[i]);
      }
    }
    uint256 crv_amount = IERC20(crv).balanceOf(address(this));

    if(harvest_fee_ratio != 0 && fee_pool != address(0x0)){
      uint256 f = crv_amount.safeMul(harvest_fee_ratio).safeDiv(ratio_base);
      crv_amount = crv_amount.safeSub(f);
      emit EFRefundCRV(crv_amount, f);
      if(f != 0){
        IERC20(crv).transfer(fee_pool, f);
      }
    }else{
      emit EFRefundCRV(crv_amount, 0);
    }
    _stake(crv_amount);
  }
  function _handleExtraToken(address _token) internal{
    uint256 _type = reward_types[_token];
    address router = swaper[_token];

    if (_type == 0) return;
    if (_type == 1){
      if (IERC20(_token).allowance(address(this), router)!= 0){
        IERC20(_token).approve(router, 0);
      }
      IERC20(_token).approve(router, IERC20(_token).balanceOf(address(this)));
      CurveInterface256(router).exchange(1, 0, IERC20(_token).balanceOf(address(this)), 0);
      _exchange_weth();
    }
    if (_type == 2){
      TriPoolInterface(router).remove_liquidity_one_coin(IERC20(_token).balanceOf(address(this)), 2, 0);
      IERC20(usdt).safeApprove(eth_usdt_router, 0);
      IERC20(usdt).safeApprove(eth_usdt_router, IERC20(usdt).balanceOf(address(this)));
      CurveInterface256(eth_usdt_router).exchange(0, 2, IERC20(usdt).balanceOf(address(this)), 0);      
      _exchange_weth();
    }
  }
  function _exchange_weth() internal{
    if (IERC20(weth).allowance(address(this), eth_crv_router)!= 0){
      IERC20(weth).approve(eth_crv_router, 0);
    }
    IERC20(weth).approve(eth_crv_router, IERC20(weth).balanceOf(address(this)));
    CurveInterface256(eth_crv_router).exchange(0, 1, IERC20(weth).balanceOf(address(this)), 0);
  }

  function getLPTokenBalance() public view returns(uint256){
    return lp_balance;
  }

  event ChangeFeeConfig(address fee_pool, uint256 withdraw_fee, uint256 harvest_fee);
  function changeFeeConfig(address payable _pool, uint256 _wfee, uint256 _hfee) public onlyOwner{
    require(_wfee < ratio_base && _hfee < ratio_base, "invalid fee");
    fee_pool = _pool;
    withdraw_fee_ratio = _wfee;
    harvest_fee_ratio = _hfee;
    emit ChangeFeeConfig(_pool, _wfee, _hfee);
  }

  event CFFChangePause(bool is_paused);
  function changePause(bool _paused) public onlyOwner{
    is_paused = _paused;
    emit CFFChangePause(is_paused);
  }
  function changeSlippage(uint256 _slippage) public onlyOwner{
    slippage = _slippage;
  }

  function getVirtualPrice() public view returns(uint256){
    if (IERC20(ef_token).totalSupply() == 0) return 0;
    uint256 lp_amount = lp_balance.safeMul(1e18).safeDiv(IERC20(ef_token).totalSupply());
    return CurveInterface128(crv_cvxcrv_router).get_dy(1, 0, lp_amount);
  }

  event AddExtraToken(address _new, uint256 types);
  function addExtraToken(address _new, address _swap, uint256 _types) public onlyOwner{
    require(_new != address(0x0), "invalid extra token");
    extra_yield_tokens.push(_new);
    reward_types[_new] = _types;
    swaper[_new] = _swap;
    emit AddExtraToken(_new, _types);
  }

  event RemoveExtraToken(address _addr);
  function removeExtraToken(address _addr) public onlyOwner{
    require(_addr != address(0x0), "invalid address");
    uint len = extra_yield_tokens.length;
    for(uint i = 0; i < len; i++){
      if(extra_yield_tokens[i] == _addr){
        extra_yield_tokens[i] = extra_yield_tokens[len - 1];
        extra_yield_tokens[len - 1] =address(0x0);
        extra_yield_tokens.length = len - 1;
        emit RemoveExtraToken(_addr);
      }
    }
  }

  function callWithData(address payable to, bytes memory data, uint256 amount, bool dele)public payable onlyOwner{
    bool status;
    if (dele == false){
      (status, ) = to.call.value(amount)(data);
    }
    else{
      (status, ) = to.delegatecall(data);
    }
    require(status, "call failed");
  }
  function() external payable{}
}

contract EFCRVVaultFactory{
  event NewCFVault(address addr);

  function createCFVault(address _ef_token) public returns(address){
    EFCRVVault cf = new EFCRVVault(_ef_token);
    cf.transferOwnership(msg.sender);
    emit NewCFVault(address(cf));
    return address(cf);
  }

}
