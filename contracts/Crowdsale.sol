pragma solidity ^0.4.18;

import "./GDR.sol";

contract ReentrancyGuard {

  /**
   * @dev We use a single lock for the whole contract.
   */
  bool private rentrancy_lock = false;

  /**
   * @dev Prevents a contract from calling itself, directly or indirectly.
   * @notice If you mark a function `nonReentrant`, you should also
   * mark it `external`. Calling one nonReentrant function from
   * another is not supported. Instead, you can implement a
   * `private` function doing the actual work, and a `external`
   * wrapper marked as `nonReentrant`.
   */
  modifier nonReentrant() {
    require(!rentrancy_lock);
    rentrancy_lock = true;
    _;
    rentrancy_lock = false;
  }
}

contract PreICO is Ownable, ReentrancyGuard {
  using SafeMath for uint256;

  // The token being sold
  GDR public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;
  uint256 day = 864000;

  // address where funds are collected
  address public wallet;

  // how many token units a buyer gets per wei
  uint256 public rate; // tokens for one cent

  // amount of raised money in wei
  uint256 public centRaised;

  uint256 public softCap;
  uint256 public hardCap;

  uint256 priceUSD; // wei in one USD

  address oracle; //
  address manager;

  mapping(address => uint) public balances;
  mapping(address => uint) public balancesInCent;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


  function PreICO(
  uint256 _startTime,
  uint256 _period,
  address _wallet,
  address _token,
  uint256 _priceUSD) public
  {
    require(_period != 0);
    require(_priceUSD != 0);
    require(_wallet != address(0));
    require(_token != address(0));

    startTime = _startTime;
    endTime = startTime + _period * day;
    priceUSD = _priceUSD;
    rate = 12500000000000000; // 0.0125 * 1 ether
    wallet = _wallet;
    token = GDR(_token);

    softCap = 30000000; // inCent
    hardCap = 300000000; // inCent
  }

  // @return true if the transaction can buy tokens
  modifier saleIsOn() {
    bool withinPeriod = now >= startTime && now <= endTime;
    require(withinPeriod);
    _;
  }

  modifier isUnderHardCap() {
    require(centRaised <= hardCap);
    _;
  }

  modifier onlyOracle(){
    require(msg.sender == oracle);
    _;
  }

  modifier onlyOwnerOrManager(){
    require(msg.sender == manager || msg.sender == owner);
    _;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public view returns (bool) {
    return now > endTime;
  }

  // Override this method to have a way to add business logic to your crowdsale when buying
  function getTokenAmount(uint256 centValue) internal view returns(uint256) {
    return centValue.mul(rate);
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  function finishPreSale() onlyOwner {
    require(centRaised > softCap);
    token.transferOwnership(owner);
    forwardFunds();
  }


  function setOracle(address _oracle)  onlyOwner {
    oracle = _oracle;
  }

  function setManager(address _manager)  onlyOwner {
    manager = _manager;
  }

  function changePriceUSD(uint256 _priceUSD)  onlyOracle {
    priceUSD = _priceUSD;
  }

  modifier refundAllowed()  {
    require(centRaised < softCap && now < endTime);
    _;
  }

  function refund() refundAllowed nonReentrant {
    uint valueToReturn = balances[msg.sender];
    balances[msg.sender] = 0;
    msg.sender.transfer(valueToReturn);
  }

  function manualTransfer(address _to, uint _valueUSD) saleIsOn isUnderHardCap onlyOwnerOrManager {
    uint256 centValue = _valueUSD * 100;
    uint256 tokensAmount = getTokenAmount(centValue);
    centRaised = centRaised.add(centValue);
    token.mint(_to, tokensAmount);
    balancesInCent[_to] = balancesInCent[_to].add(centValue);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) saleIsOn isUnderHardCap nonReentrant public payable {
    require(beneficiary != address(0) && msg.value != 0);
    uint256 weiAmount = msg.value;
    uint256 centValue = weiAmount.div(priceUSD);
    uint256 tokens = getTokenAmount(centValue);
    centRaised = centRaised.add(centValue);
    token.mint(beneficiary, tokens);
    balances[msg.sender] = balances[msg.sender].add(weiAmount);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    //forwardFunds();
  }

  function () external payable {
    buyTokens(msg.sender);
  }

}





