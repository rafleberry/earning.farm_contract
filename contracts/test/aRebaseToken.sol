pragma solidity >=0.4.21 <0.6.0;

import "../erc20/IERC20.sol";
import "../utils/Ownable.sol";


interface ILido{
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
}
contract aRebaseToken is IERC20, Ownable{
    string public symbol;
    string public  name;
    uint8 public decimals;
    uint public _totalSupply;
    address public token_issuer;
    string public announcement;
    uint public index;

    address public indexer;
    address public vault;
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;


    constructor(string memory _name, string memory _symbol) public {
        symbol = _symbol;
        name = _name;
        decimals = 18;
        _totalSupply = 0;
        index = 1e18;
    }
    function setIndexer(address _index) public {
        indexer = _index;
    }

    function setIndex(uint256 _index) public{
        index = _index;
    }

    function totalSupply() public view returns (uint) {
        return _totalSupply * getIndex() / 1e18;
    }

    function getIndex() public view returns(uint){
        if (indexer == address(0x0)) return index;
        return ILido(indexer).getPooledEthByShares(1e18);
    }

    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner] * getIndex() / 1e18;
    }

    function transfer(address to, uint tokens) public returns(bool){
        uint amount = tokens * 1e18 / getIndex();
        require(balances[msg.sender] >= amount, "rabase token: not enough balance");
        balances[msg.sender] = balances[msg.sender] - amount;
        balances[to] = balances[to] + amount;
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function approve(address spender, uint tokens) public returns(bool){
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public returns(bool){
        uint amount = tokens * 1e18 / getIndex();
        require(balances[from] >= amount, "rabase token: not enough balance");
        balances[from] = balances[from] - amount;
        require(allowed[from][msg.sender] >= tokens, "rabase token: not enough allowance");
        allowed[from][msg.sender] = allowed[from][msg.sender] - tokens;
        balances[to] = balances[to] + amount;
        emit Transfer(from, to, tokens);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function generateTokens(address account, uint num) public onlyOwner returns(bool){
      if(account == address(0)) return false;
      uint amount = num * 1e18 / getIndex();
      balances[account] += amount;
      _totalSupply += amount;

      emit Transfer(address(0), account, num);
      return true;
    }
    function destroyTokens(address account, uint num) public onlyOwner returns(bool){
      if(account == address(0)) return false;
      uint amount = num * 1e18 / getIndex();
      require(balances[account] >= amount, "rabase token: not enough balance");
      balances[account] -= amount;
      _totalSupply -= amount;

      emit Transfer(address(0), account, num);
      return true;
    }
}
