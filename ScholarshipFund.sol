// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Scholarship Fund Management Contract
 * @dev Manages scholarship applications, donations, and fund distribution
 * @notice Features:
 * - Secure ETH donations with donation tracking
 * - Student applications with approval process
 * - Protected withdrawals with reentrancy guard
 * - Owner controls with restricted privileges
 */
contract ScholarshipFund is ReentrancyGuard {
    // ----------------- State Variables -----------------
    address public owner;
    uint public totalReservedFunds;
    uint public maxRequestAmount = 5 ether;
    
    /**
     * @dev Application structure optimized for storage
     * @notice Packed to use 1 storage slot (32 bytes):
     * - age: uint16 (2 bytes)
     * - approved: bool (1 byte)
     * - name/course: bytes32 (32 bytes each)
     */
    struct Application {
        bytes32 nameHash;       // Hash of student name
        bytes32 courseHash;     // Hash of course name
        uint16 age;             // Student age
        uint requestedAmount;   // Wei amount requested
        bool approved;          // Approval status
    }

    mapping(address => Application) public applications;
    mapping(address => uint) public donations;

    // ----------------- Events -----------------
    event Donated(address indexed donor, uint amount);
    event Applied(address indexed student, bytes32 nameHash, uint requestedAmount);
    event Approved(address indexed student, uint amount);
    event Withdrawn(address indexed student, uint amount);
    event Rejected(address indexed student);
    event MaxRequestUpdated(uint newAmount);

    // ----------------- Modifiers -----------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Owner only");
        _;
    }

    // ----------------- Constructor -----------------
    constructor() {
        owner = msg.sender;
    }

    // ----------------- Core Functions -----------------

    /**
     * @dev Accept donations and track donors
     * @notice ETH sent directly to contract will be rejected
     */
    function donate() external payable {
        require(msg.value > 0, "Minimum 1 wei required");
        donations[msg.sender] += msg.value;
        emit Donated(msg.sender, msg.value);
    }

    /**
     * @dev Submit scholarship application
     * @param _name Student name (converted to bytes32 hash)
     * @param _age Student age (2 bytes)
     * @param _course Course name (converted to bytes32 hash)
     * @param _requestedAmount Requested amount in wei
     */
    function applyForScholarship(
        string calldata _name,
        uint16 _age,
        string calldata _course,
        uint _requestedAmount
    ) external {
        require(msg.sender != owner, "Owner cannot apply");
        require(_requestedAmount <= maxRequestAmount, "Exceeds max request");
        require(_requestedAmount > 0, "Amount must be > 0");
        require(applications[msg.sender].requestedAmount == 0, "Already applied");

        applications[msg.sender] = Application({
            nameHash: keccak256(abi.encodePacked(_name)),
            courseHash: keccak256(abi.encodePacked(_course)),
            age: _age,
            requestedAmount: _requestedAmount,
            approved: false
        });

        emit Applied(msg.sender, applications[msg.sender].nameHash, _requestedAmount);
    }

    /**
     * @dev Approve application and reserve funds
     * @param _student Applicant address to approve
     */
    function approveScholarship(address _student) external onlyOwner {
        Application storage app = applications[_student];
        require(app.requestedAmount > 0, "Application not found");
        require(!app.approved, "Already approved");
        
        uint availableBalance = address(this).balance - totalReservedFunds;
        require(availableBalance >= app.requestedAmount, "Insufficient funds");

        totalReservedFunds += app.requestedAmount;
        app.approved = true;

        emit Approved(_student, app.requestedAmount);
    }

    /**
     * @dev Withdraw approved funds (non-reentrant)
     */
    function withdraw() external nonReentrant {
        Application storage app = applications[msg.sender];
        require(app.approved, "Not approved");
        require(app.requestedAmount > 0, "Already withdrawn");

        uint amount = app.requestedAmount;
        app.requestedAmount = 0;
        totalReservedFunds -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    // ----------------- Management Functions -----------------

    /**
     * @dev Reject an application
     * @param _student Applicant address to reject
     */
    function rejectApplication(address _student) external onlyOwner {
        require(applications[_student].requestedAmount > 0, "Application not found");
        delete applications[_student];
        emit Rejected(_student);
    }

    /**
     * @dev Update maximum allowed request amount
     * @param _newAmount New maximum in wei
     */
    function setMaxRequestAmount(uint _newAmount) external onlyOwner {
        require(_newAmount > 0, "Invalid amount");
        maxRequestAmount = _newAmount;
        emit MaxRequestUpdated(_newAmount);
    }

    // ----------------- Utility Functions -----------------

    /**
     * @dev Get contract ETH balance
     * @return Current contract balance in wei
     */
    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    /**
     * @dev Get total available balance (excluding reserved funds)
     * @return Available balance in wei
     */
    function getAvailableBalance() external view returns (uint) {
        return address(this).balance - totalReservedFunds;
    }

    // ----------------- Safety Features -----------------

    /**
     * @dev Block accidental ETH transfers
     */
    receive() external payable {
        revert("Use donate() function");
    }

    /**
     * @dev Prevent ETH transfers via fallback
     */
    fallback() external payable {
        revert("Direct transfers not allowed");
    }
}