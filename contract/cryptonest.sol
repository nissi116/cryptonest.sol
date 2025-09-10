// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CryptoNest
 * @dev A decentralized investment platform for crypto asset management
 * @author CryptoNest Team
 */
contract Project {
    
    // State variables
    address public owner;
    uint256 public totalInvestors;
    uint256 public totalInvestmentPools;
    uint256 public platformFeePercentage = 2; // 2% platform fee
    
    // Structs
    struct InvestmentPool {
        uint256 poolId;
        string name;
        string description;
        address creator;
        uint256 targetAmount;
        uint256 currentAmount;
        uint256 minInvestment;
        uint256 maxInvestment;
        bool isActive;
        uint256 createdAt;
        uint256 deadline;
    }
    
    struct Investor {
        address investorAddress;
        uint256 totalInvested;
        uint256[] poolsInvested;
        bool isRegistered;
        uint256 joinedAt;
    }
    
    // Mappings
    mapping(uint256 => InvestmentPool) public investmentPools;
    mapping(address => Investor) public investors;
    mapping(uint256 => mapping(address => uint256)) public poolInvestments; // poolId => investor => amount
    mapping(address => uint256) public platformEarnings;
    
    // Events
    event PoolCreated(uint256 indexed poolId, string name, address indexed creator, uint256 targetAmount);
    event InvestmentMade(uint256 indexed poolId, address indexed investor, uint256 amount);
    event InvestorRegistered(address indexed investor, uint256 timestamp);
    event FundsWithdrawn(uint256 indexed poolId, address indexed creator, uint256 amount);
    event PoolClosed(uint256 indexed poolId, bool successful);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredInvestor() {
        require(investors[msg.sender].isRegistered, "Must be a registered investor");
        _;
    }
    
    modifier validPool(uint256 _poolId) {
        require(_poolId < totalInvestmentPools, "Invalid pool ID");
        require(investmentPools[_poolId].isActive, "Pool is not active");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        totalInvestors = 0;
        totalInvestmentPools = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new investment pool
     * @param _name Name of the investment pool
     * @param _description Description of the investment strategy
     * @param _targetAmount Target amount to raise (in wei)
     * @param _minInvestment Minimum investment amount (in wei)
     * @param _maxInvestment Maximum investment amount (in wei)
     * @param _durationInDays Duration of the fundraising period in days
     */
    function createInvestmentPool(
        string memory _name,
        string memory _description,
        uint256 _targetAmount,
        uint256 _minInvestment,
        uint256 _maxInvestment,
        uint256 _durationInDays
    ) external {
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_minInvestment > 0, "Minimum investment must be greater than 0");
        require(_maxInvestment >= _minInvestment, "Maximum investment must be >= minimum");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_name).length > 0, "Pool name cannot be empty");
        
        // Register investor if not already registered
        if (!investors[msg.sender].isRegistered) {
            _registerInvestor(msg.sender);
        }
        
        uint256 poolId = totalInvestmentPools;
        
        investmentPools[poolId] = InvestmentPool({
            poolId: poolId,
            name: _name,
            description: _description,
            creator: msg.sender,
            targetAmount: _targetAmount,
            currentAmount: 0,
            minInvestment: _minInvestment,
            maxInvestment: _maxInvestment,
            isActive: true,
            createdAt: block.timestamp,
            deadline: block.timestamp + (_durationInDays * 1 days)
        });
        
        totalInvestmentPools++;
        
        emit PoolCreated(poolId, _name, msg.sender, _targetAmount);
    }
    
    /**
     * @dev Core Function 2: Invest in a specific pool
     * @param _poolId ID of the investment pool
     */
    function investInPool(uint256 _poolId) external payable validPool(_poolId) {
        InvestmentPool storage pool = investmentPools[_poolId];
        
        require(block.timestamp < pool.deadline, "Investment period has ended");
        require(msg.value >= pool.minInvestment, "Investment below minimum amount");
        require(msg.value <= pool.maxInvestment, "Investment exceeds maximum amount");
        require(pool.currentAmount + msg.value <= pool.targetAmount, "Investment would exceed target");
        
        // Register investor if not already registered
        if (!investors[msg.sender].isRegistered) {
            _registerInvestor(msg.sender);
        }
        
        // Update pool current amount
        pool.currentAmount += msg.value;
        
        // Update investor records
        if (poolInvestments[_poolId][msg.sender] == 0) {
            investors[msg.sender].poolsInvested.push(_poolId);
        }
        poolInvestments[_poolId][msg.sender] += msg.value;
        investors[msg.sender].totalInvested += msg.value;
        
        emit InvestmentMade(_poolId, msg.sender, msg.value);
        
        // Check if pool target is reached
        if (pool.currentAmount >= pool.targetAmount) {
            pool.isActive = false;
            emit PoolClosed(_poolId, true);
        }
    }
    
    /**
     * @dev Core Function 3: Withdraw funds from completed pool (creator only)
     * @param _poolId ID of the investment pool
     */
    function withdrawPoolFunds(uint256 _poolId) external {
        InvestmentPool storage pool = investmentPools[_poolId];
        
        require(msg.sender == pool.creator, "Only pool creator can withdraw");
        require(!pool.isActive || block.timestamp >= pool.deadline, "Pool still active or not expired");
        require(pool.currentAmount > 0, "No funds to withdraw");
        
        uint256 totalAmount = pool.currentAmount;
        uint256 platformFee = (totalAmount * platformFeePercentage) / 100;
        uint256 creatorAmount = totalAmount - platformFee;
        
        // Reset pool amount to prevent re-entrancy
        pool.currentAmount = 0;
        pool.isActive = false;
        
        // Transfer platform fee to owner
        platformEarnings[owner] += platformFee;
        
        // Transfer remaining funds to pool creator
        payable(pool.creator).transfer(creatorAmount);
        
        emit FundsWithdrawn(_poolId, pool.creator, creatorAmount);
        emit PoolClosed(_poolId, totalAmount >= pool.targetAmount);
    }
    
    // Internal function to register investor
    function _registerInvestor(address _investor) internal {
        if (!investors[_investor].isRegistered) {
            investors[_investor] = Investor({
                investorAddress: _investor,
                totalInvested: 0,
                poolsInvested: new uint256[](0),
                isRegistered: true,
                joinedAt: block.timestamp
            });
            
            totalInvestors++;
            emit InvestorRegistered(_investor, block.timestamp);
        }
    }
    
    // View functions
    function getPoolDetails(uint256 _poolId) external view returns (
        string memory name,
        string memory description,
        address creator,
        uint256 targetAmount,
        uint256 currentAmount,
        uint256 minInvestment,
        uint256 maxInvestment,
        bool isActive,
        uint256 deadline
    ) {
        InvestmentPool memory pool = investmentPools[_poolId];
        return (
            pool.name,
            pool.description,
            pool.creator,
            pool.targetAmount,
            pool.currentAmount,
            pool.minInvestment,
            pool.maxInvestment,
            pool.isActive,
            pool.deadline
        );
    }
    
    function getInvestorPoolsCount(address _investor) external view returns (uint256) {
        return investors[_investor].poolsInvested.length;
    }
    
    function getInvestorInvestment(uint256 _poolId, address _investor) external view returns (uint256) {
        return poolInvestments[_poolId][_investor];
    }
    
    // Owner functions
    function updatePlatformFee(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 10, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }
    
    function withdrawPlatformEarnings() external onlyOwner {
        uint256 earnings = platformEarnings[owner];
        require(earnings > 0, "No earnings to withdraw");
        
        platformEarnings[owner] = 0;
        payable(owner).transfer(earnings);
    }
    
    // Emergency function to pause a pool
    function pausePool(uint256 _poolId) external onlyOwner {
        require(_poolId < totalInvestmentPools, "Invalid pool ID");
        investmentPools[_poolId].isActive = false;
    }
}
