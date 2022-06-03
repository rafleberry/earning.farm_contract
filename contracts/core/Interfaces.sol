pragma solidity >=0.4.21 <0.6.0;

interface IWETH {
    function withdraw(uint256) external;
}
interface IAAVE {
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);

    function getUserAccountData(address)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

interface ILido {
    function submit(address) external payable;
}

interface IBalancer {
    function flashLoan(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external;
}

interface IBalancerFee{
    function getFlashLoanFeePercentage() external view returns (uint256);//18 decimal
}


interface ICurve{
    function get_dy(int128 i, int128 j, uint256 dx) external view returns(uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns(uint256);
}

contract UniswapV3Interface{
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to) external payable returns (uint256 amountOut);
}
contract CurveInterface256{
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable returns(uint256);//change i to j
    //0 weth, 1 crv
}
contract CurveInterface128{
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns(uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns(uint256);
    //0 crv, 1 cvxcrv
}
contract TriPoolInterface{
    function remove_liquidity_one_coin(uint256 _token_amount, uint128 i, uint256 min_amount) external;//DAI, USDC, USDT
}
contract ConvexInterface{
    function stake(uint256 amount) public returns(bool);
    function withdraw(uint256 amount, bool claim) public returns(bool);
    function getReward() external returns(bool);
    function withdrawAll(bool claim) public;
}
contract ChainlinkInterface{
    function latestAnswer() external view returns (int256);
}
