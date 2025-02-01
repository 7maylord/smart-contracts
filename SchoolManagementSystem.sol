// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract SchoolManagementSystem {
    address public admin;
    uint256 public studentCount;
    
    struct Student {
        uint256 id;
        string name;
    }
    
    mapping(uint256 => Student) private students;
    mapping(uint256 => bool) private isRegistered; // To track if student is registered

    event StudentRegistered(uint256 indexed id, string name);
    event StudentRemoved(uint256 indexed id);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    constructor() {
        admin = msg.sender;
    }
    
    function registerStudent(uint256 _id, string memory _name) external onlyAdmin {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(!isRegistered[_id], "Student ID already exists");
        
        students[_id] = Student(_id, _name);
        isRegistered[_id] = true;  // Mark student as registered
        studentCount++;
        
        emit StudentRegistered(_id, _name);
    }
    
    function removeStudent(uint256 _id) external onlyAdmin {
        require(isRegistered[_id], "Student does not exist");
        
        delete students[_id];
        isRegistered[_id] = false; // Mark student as removed
        studentCount--;
        
        emit StudentRemoved(_id);
    }
    
    function getStudentById(uint256 _id) external view returns (string memory) {
        require(isRegistered[_id], "Student not found");
        return students[_id].name;
    }
    
    function getAllStudents() external view returns (Student[] memory) {
        uint256 activeCount = studentCount;
        Student[] memory allStudents = new Student[](activeCount);
        uint256 index = 0;
        
        // Only iterate through registered students
        for (uint256 i = 0; i < activeCount; i++) {
            if (isRegistered[i]) {
                allStudents[index] = students[i];
                index++;
            }
        }
        
        return allStudents;
    }
}
