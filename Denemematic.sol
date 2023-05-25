/*Anladım. SoftCap ve HardCap kaldırıldı ve yerine yalnızca satışın başlangıç ve bitiş süresi tanımlandı. Satın alma işlemi gerçekleştirildiği anda tokenler otomatik olarak müşterinin hesabına aktarılacak şekilde düzenlendi. Siz istediğiniz zaman kontrat sahibi olarak toplam token sayısını ve transfer edilebilir token sayısını kontrol edebileceksiniz. Güncellenmiş kod aşağıdaki gibidir:*\

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract MyTokenSale is ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20;

    IERC20 private _token;

    uint256 private _tokenDecimals;

    uint256 private _rate;

    uint256 private _weiRaised;

    uint256 public availableTokensICO;

    mapping(address => uint256) private _contributions;

    address payable private _wallet;

    uint256 public minPurchase = 0.1 ether;

    uint256 public maxPurchase = 100 ether;

    uint256 public endICO;

    address public constant ARB_ADDRESS = 0x912CE59144191C1204E64559FE8253a0e49E6548;

    IERC20 private arbToken;

    bool public saleStarted;

    uint256 public saleDuration = 60 days;

    constructor(

        uint256 rate,

        address payable wallet,

        IERC20 token,

        uint256 tokenDecimals

    ) {

        require(rate > 0, "Pre-Sale: rate is zero");

        require(wallet != address(0), "Pre-Sale: wallet is zero address");

        require(address(token) != address(0), "Pre-Sale: token is zero address");

        _rate = rate;

        _wallet = wallet;

        _token = token;

        _tokenDecimals = tokenDecimals;

        arbToken = IERC20(ARB_ADDRESS);

        availableTokensICO = token.balanceOf(address(this));

    }

   receive () external payable {

        buyTokens(msg.sender);

    }

    function buyTokens(address beneficiary) public nonReentrant payable {

        require(saleStarted, "Pre-Sale: sale not started yet");

        uint256 weiAmount = msg.value;

        require(beneficiary != address(0), "Pre-Sale: beneficiary is zero address");

        require(weiAmount >= minPurchase, "Pre-Sale: minimum purchase amount not reached");

        require(_weiRaised.add(weiAmount) <= availableTokensICO.div(_rate), "Pre-Sale: not enough tokens left for sale");

        require(_contributions[beneficiary].add(weiAmount) <= maxPurchase, "Pre-Sale: maximum purchase amount exceeded");

        uint256 tokens = weiAmount.mul(_rate);

        _weiRaised = _weiRaised.add(weiAmount);

        availableTokensICO = availableTokensICO.sub(tokens);

        _contributions[beneficiary] = _contributions[beneficiary].add(weiAmount);

        emit TokensPurchased(msg.sender, beneficiary, weiAmount, tokens);

        _token.safeTransfer(beneficiary, tokens);

    }

    function setRate(uint256 rate) external onlyOwner {

        require(rate > 0, "Pre-Sale: rate is zero");

        _rate = rate;

    }

    function setMinPurchase(uint256 _minPurchase) external onlyOwner {

        require(_minPurchase > 0, "Pre-Sale: minimum purchase amount can't be zero");

        minPurchase = _minPurchase;

    }

    function setMaxPurchase(uint256 _maxPurchase) external onlyOwner {

        require(_maxPurchase > 0, "Pre-Sale: maximum purchase amount can't be zero");

        maxPurchase = _maxPurchase;

    }

    function startPresale() external onlyOwner {

        require(availableTokensICO > 0, "Pre-Sale: no tokens left to sale");

        saleStarted = true;

        endICO = block.timestamp + saleDuration;

    }

    function endPresale() external onlyOwner {

        require(block.timestamp >= endICO, "Pre-Sale: sale not ended yet");

        _wallet.transfer(address(this).balance);

    }

    function withdrawTokens(uint256 amount) external onlyOwner {

        require(amount > 0, "Pre-Sale: amount can't be zero");

        require(_token.balanceOf(address(this)) >= amount, "Pre-Sale: not enough tokens for withdrawal");

        _token.safeTransfer(_wallet, amount);

    }

    function getContractBalance() external view onlyOwner returns (uint256) {

        return address(this).balance;

    }

    function getTokensLeft() external view onlyOwner returns (uint256) {

        return _token.balanceOf(address(this));

    }

    function getContributions(address beneficiary) external view returns (uint256) {

        return _contributions[beneficiary];

    }

}
