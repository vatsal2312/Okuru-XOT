// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _transferOwnership(_msgSender());
    }
    modifier onlyOwner() {
        _checkOwner();
        _;
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);
    bool private _paused;
    constructor() {
        _paused = false;
    }
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }
    modifier whenPaused() {
        _requirePaused();
        _;
    }
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
contract Stake is Pausable, Ownable, ReentrancyGuard {
    IERC20 XOTToken;
    uint256 public Duration = 41472000;    //  Days (16 * 30 * 24 * 60 * 60)
    uint8 public totalStakers;
    uint256 rewardAmount ;
    mapping (address => uint256 ) _balances;
    struct StakeInfo {        
        uint256 startTime;
        uint256 endTime;        
        uint256 amount; 
        uint256 claimed;       
    }
    event Staked(address indexed from, uint256 amount);
    event Claimed(address indexed from, uint256 amount);
    event AddRewardTokens(uint256);
    mapping(address => StakeInfo) public stakeInfos;
    mapping(address => bool) public addressStaked;
    constructor(IERC20 _tokenAddress,uint256 amount) {
        require(address(_tokenAddress) != address(0),"Token Address cannot be address 0");                
        XOTToken = _tokenAddress;   
        XOTToken.transferFrom(msg.sender, address(this), amount); 
        rewardAmount = amount ;
        _balances[address(this)] = rewardAmount;   
        totalStakers = 0;
    }    
    function claimReward() external returns (bool){
        require(addressStaked[_msgSender()] == true, "You are not participated");
        require(stakeInfos[_msgSender()].endTime < block.timestamp, "Stake Time is not over yet");
        require(stakeInfos[_msgSender()].claimed == 0, "Already claimed");
        stakeInfos[_msgSender()].claimed ==  stakeInfos[_msgSender()].amount + (stakeInfos[_msgSender()].amount * 25 / 1000);
        XOTToken.transfer(_msgSender(),  stakeInfos[_msgSender()].amount + (stakeInfos[_msgSender()].amount * 25 / 1000));
        emit Claimed(_msgSender(),  stakeInfos[_msgSender()].amount + (stakeInfos[_msgSender()].amount * 25 / 1000));
        return true;
    }
    function getTokenExpiry() external view returns (uint256) {
        require(addressStaked[_msgSender()] == true, "You are not participated");
        return stakeInfos[_msgSender()].endTime;
    }
    function stakeToken(uint256 stakeAmount) external whenNotPaused {
        require(stakeAmount >0, "Stake amount should be correct");
        require(addressStaked[_msgSender()] == false, "You already participated");
        require(XOTToken.balanceOf(_msgSender()) >= stakeAmount, "Insufficient Balance");
           XOTToken.transferFrom(_msgSender(), address(this), stakeAmount);
            totalStakers++;
            addressStaked[_msgSender()] = true;
            stakeInfos[_msgSender()] = StakeInfo({                
                startTime: block.timestamp,
                endTime: block.timestamp + Duration,
                amount: stakeAmount,
                claimed: 0
            });
        emit Staked(_msgSender(), stakeAmount);
    }    
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }
    function AddRewardToken(uint256 amount) public onlyOwner{
        rewardAmount = rewardAmount + amount;
        XOTToken.transferFrom(msg.sender, address(this),rewardAmount) ; 
        _balances[address(this)] = rewardAmount;
        emit AddRewardTokens(amount);
    }
}
