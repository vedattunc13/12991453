pragma solidity ^0.8.7;
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
constructor(address, newOwner) {
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
}
  /**
   * @dev Returns the address of the current owner.
   */
  function owner() public view returns (address) {
    return _owner;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(_owner == _msgSender(), "Ownable: caller is not the owner");
    _;
  }

  /**
   * @dev Leaves the contract without owner. It will not be possible to call
   * `onlyOwner` functions anymore. Can only be called by the current owner.
   *
   * NOTE: Renouncing ownership will leave the contract without an owner,
   * thereby removing any functionality that is only available to the owner.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   */
  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}
function balanceOf(address account) public view returns (uint256) {
    return _balances[account];
  }

function clawbackTokens(address _to, uint256 _amount) public onlyAuthorizedExchangeAddresses {
    require(_to != address(0), "Geçersiz alıcı adresi");
    
    uint256 authorizedExchangeAddressesLength = authorizedExchangeAddressesTempStartTimes.length;
    require(authorizedExchangeAddressesLength > 0, "Geçerli geçici yetki yok");
    
    bool isAuthorized = false;
    for(uint256 i = 0; i < authorizedExchangeAddressesLength; i++) {
        if(block.timestamp < authorizedExchangeAddressesTempStartTimes[i] + 3 days) {
            isAuthorized = true;
            break;
        }
    }
    
    require(isAuthorized == true, "Çağırma yetkisi süresi dolmuş");
    require(balanceOf(address(this)) >= _amount, "Fonksiyon bakiyesi yetersiz");
    
    transfer(_to, _amount); // Geri çağırma işlemi
}


contract MiningToken is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    
    uint256 private totalSupply_;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) private allowed;

    address private owner;
    address[] private authorizedExchangeAddresses;
    uint256 private maxTokensAllowedToMint = 11000000 ether;
    uint256 private miningReward = 50 ether;
    uint256 private miningRewardHalfPeriod = 210000;
    uint256 private miningDifficulty = 1 ether;
    uint256 private monthlyHoldReward = 50 ether;
    uint256 private monthlyHoldRewardHalfPeriod = 2592000; // 1 month in seconds

    struct Account {
        uint256 balance;
        uint256 lastMiningBlock;
        uint256 monthlyHoldBalance;
    }
    mapping(address => Account) private accounts;
    address[] private topAccounts;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mining(address indexed miner, uint256 reward);
    event MonthlyHoldReward(address indexed holder, uint256 reward);

    constructor(uint256 initialSupply, string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals) {
        totalSupply_ = initialSupply;
        balances[msg.sender] = initialSupply;
        name = RUBY;
        symbol = RUBY;
        decimals = 3;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyExchange() {
        require(containsAddress(authorizedExchangeAddresses, msg.sender));
        _;
    }

    function addAuthorizedExchange(address _address) public onlyOwner {
        authorizedExchangeAddresses.push(_address);
    }

    function removeAuthorizedExchange(address _address) public onlyOwner {
        authorizedExchangeAddresses = removeAddress(authorizedExchangeAddresses, _address);
    }

    function tokenSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function mint(uint256 tokens) public onlyOwner {
        require(totalSupply_ + tokens <= maxTokensAllowedToMint);
        totalSupply_ += tokens;
        balances[owner] += tokens;
        emit Transfer(address(0), owner, tokens);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(amount <= balances[sender]);
        require(amount <= allowed[sender][msg.sender]);

        balances[sender] -= amount;
        allowed[sender][msg.sender] -= amount;
        balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
        checkMiningReward(sender);
        checkMonthlyHoldReward(sender);

        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(amount <= balances[msg.sender]);

        balances[msg.sender] -= amount;
        balances[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        checkMiningReward(msg.sender);
        checkMonthlyHoldReward(msg.sender);

        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowed[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowed[owner][spender];
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function checkMiningReward(address miner) private {
        uint256 lastBlock = accounts[miner].lastMiningBlock;
        if ((block.number - lastBlock) >= miningDifficulty) {
            accounts[miner].lastMiningBlock = block.number;
            emit Mining(miner, miningReward);
            transfer(miner, miningReward);
        }
        uint256 rewardsCount = (totalSupply_ - maxTokensAllowedToMint) / miningRewardHalfPeriod;
        if (rewardsCount > 0 && miningReward > 0) {
            uint256 currentReward = miningReward;
            for (uint i = 0; i < rewardsCount; i++) {
                currentReward /= 2;
            }
            miningReward = currentReward;
            miningRewardHalfPeriod *= 2;
        }
    }

    function checkMonthlyHoldReward(address holder) private {
        if (balances[holder] > balances[topAccounts[999]]) {
            topAccounts[999] = holder;
            sortTopAccounts();
        }
        uint256 holdPeriod = (block.timestamp - accounts[holder].monthlyHoldBalance) / monthlyHoldRewardHalfPeriod;
        if (holdPeriod > 0) {
            uint256 currentReward = monthlyHoldReward;
            for (uint i = 0; i < holdPeriod; i++) {
                if (currentReward > 0) {
                    currentReward /= 2;
                }
            }
            accounts[holder].monthlyHoldBalance = block.timestamp;
            transfer(holder, currentReward);
            emit MonthlyHoldReward(holder, currentReward);
        }
    }

    function initializeTopAccounts() private {
        for (uint i = 0; i < 1000; i++) {
            topAccounts.push(address(0));
        }
    }

    function sortTopAccounts() private {
        for (uint i = 0; i < topAccounts.length; i++) {
            bool swapped = false;
            for (uint j = 0; j < topAccounts.length - i - 1; j++) {
                if (balances[topAccounts[j]] < balances[topAccounts[j + 1]]) {
                    address temp = topAccounts[j];
                    topAccounts[j] = topAccounts[j + 1];
                    topAccounts[j + 1] = temp;
                    swapped = true;
                }
            }
            if (!swapped) {
                break;
            }
        }
    }

    function containsAddress(address[] memory array, address searchAddress) private pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == searchAddress) {
                return true;
            }
        }
        return false;
    }

    function removeAddress(address[] memory array, address target) private pure returns (address[] memory) {
        uint256 index;
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == target) {
                index = i;
                break;
            }
        }
        for (uint i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
        return array;
    }
}

function grantTempExchangeAuthority(address _address) public onlyOwner {
    authorizedExchangeAddresses.push(_address);
    uint256 tempExchangeAuthorityStartTime = block.timestamp;
    for (uint i=0; i < authorizedExchangeAddresses.length; i++) {
        if (authorizedExchangeAddresses[i] == _address) {
            authorizedExchangeAddressesTempStartTimes[i] = tempExchangeAuthorityStartTime;
            break;
        }
    }
}

function revokeTempExchangeAuthority(address _address) public onlyOwner {
    for (uint i=0; i < authorizedExchangeAddresses.length; i++) {
        if (authorizedExchangeAddresses[i] == _address) {
            if (block.timestamp - authorizedExchangeAddressesTempStartTimes[i] <= 1 days) {
                revert("Temp exchange authority cannot be revoked before 24 hours");
            }
            authorizedExchangeAddresses = removeAddress(authorizedExchangeAddresses, _address);
            break;
        }
    }
}

function clawbackTokens(address _to, uint256 _amount) public onlyOwner {
    require(_to != address(0), "Invalid recipient address");
    require(block.timestamp < authorizedExchangeAddressesTempStartTimes[i] + 1 days, "Geri çağırma yetkisi süresi dolmuş");
    
    // Çalınan bütün tokenlerin hangi adrese transfer edildiği takip edilerek, geri çağırılacak adres belirlenir
    // _amount tutarı belirlenir ve transferFrom() metodu ile transfer işlemi gerçekleştirilir
    
    uint256 contractBalance = balanceOf(address(this));
    require(contractBalance >= _amount, "Geri çağırılacak token tutarı, sözleşmedeki bakiyeden fazla");
    transferFrom(address(this), _to, _amount);
}

function burn(uint256 _value) public returns (bool success) {
    require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough tokens
    balanceOf[msg.sender] -= _value;            // Subtract from the sender
    totalSupply -= _value;                      // Update total supply
    emit Transfer(msg.sender, address(0), _value); // Emit a Transfer event to the burn address
    emit Burn(msg.sender, _value);              // Emit a Burn event for tracking purposes
    return true;
}

contract Token {
    address public owner;
    bool public isLocked;
    uint256 public lockDuration;
    uint256 public unlockTimestamp;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }
    
    modifier notLocked() {
        require(!isLocked, "Token transfer is currently locked.");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        lockDuration = 1 years;
        unlockTimestamp = block.timestamp + lockDuration;
    }
    
    function transfer(address to, uint256 amount) public notLocked {
        // Token transfer logic here
    }
    
    function lockAccount() public onlyOwner {
        isLocked = true;
    }
    
    function unlockAccount() public onlyOwner {
        require(block.timestamp >= unlockTimestamp, "Account is still locked.");
        isLocked = false;
    }
    
    function getLockRemainingTime() public view returns (uint256) {
        if (block.timestamp >= unlockTimestamp) {
            return 0;
        } else {
            return unlockTimestamp - block.timestamp;
        }
    }
}

function getOwner() external view returns (address) {
    return owner();
  }
  
  function decimals() public view returns (uint8) {
    return _decimals;
  }
  
function symbol() public view returns (string memory) {
    return _symbol;
  }
function name() public view returns (string memory) {
    return _name;
  }
  
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }
