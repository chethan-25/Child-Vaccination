// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract VaccinationRegistry is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;
    
    struct Child {
        string name;
        uint256 dateOfBirth;
        string parentName;
        string contactInfo;
        address parentAddress;
        address registeredByHospital;
        string hospitalName;
        bool isRegistered;
        uint256 registrationDate;
    }
    
    struct VaccinationRecord {
        string vaccineName;
        uint256 dateAdministered;
        string hospitalName;
        address administeredBy;
        string batchNumber;
        uint256 nextDueDate;
        bool isVerified;
        string ipfsHash;
        string qrCodeHash; // For QR code generation
    }
    
    struct Hospital {
        string name;
        string licenseNumber;
        string contactInfo;
        bool isAuthorized;
        uint256 registrationDate;
    }
    
    mapping(uint256 => Child) public children;
    mapping(uint256 => VaccinationRecord[]) public vaccinationHistory;
    mapping(address => Hospital) public hospitals;
    mapping(address => bool) public authorizedHospitals;
    mapping(uint256 => string) public tokenURIs;
    mapping(address => uint256[]) public parentToChildren; // Track parent's children
    mapping(uint256 => uint256[]) public vaccinationReminders; // Token ID to due dates
    
    event ChildRegistered(uint256 indexed tokenId, string name, address indexed parent, address indexed hospital);
    event VaccinationRecorded(uint256 indexed tokenId, string vaccineName, uint256 dateAdministered, string qrCodeHash);
    event HospitalRegistered(address indexed hospital, string name);
    event HospitalAuthorized(address indexed hospital, bool authorized);
    event ReminderTriggered(uint256 indexed tokenId, string vaccineName, uint256 dueDate);
    event QRCodeGenerated(uint256 indexed tokenId, uint256 vaccinationIndex, string qrCodeHash);
    
    modifier onlyAuthorizedHospital() {
        require(authorizedHospitals[msg.sender], "Not authorized hospital");
        _;
    }
    
    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }
    
    modifier onlyParentOrHospital(uint256 tokenId) {
        require(
            ownerOf(tokenId) == msg.sender || 
            children[tokenId].registeredByHospital == msg.sender,
            "Not authorized"
        );
        _;
    }
    
    constructor() ERC721("VaccinationNFT", "VNFT") {}
    
    // Hospital registers themselves first
    function registerHospital(
        string memory _name,
        string memory _licenseNumber,
        string memory _contactInfo
    ) public {
        require(!hospitals[msg.sender].isAuthorized, "Hospital already registered");
        
        hospitals[msg.sender] = Hospital({
            name: _name,
            licenseNumber: _licenseNumber,
            contactInfo: _contactInfo,
            isAuthorized: false, // Needs owner approval
            registrationDate: block.timestamp
        });
        
        emit HospitalRegistered(msg.sender, _name);
    }
    
    // MAIN CHANGE: Only hospitals can register children, NFT goes to parent
    function registerChild(
        string memory _name,
        uint256 _dateOfBirth,
        string memory _parentName,
        string memory _contactInfo,
        address _parentAddress,
        string memory _tokenURI
    ) public onlyAuthorizedHospital returns (uint256) {
        require(_parentAddress != address(0), "Invalid parent address");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        // Mint NFT to parent address (not hospital)
        _mint(_parentAddress, newTokenId);
        
        children[newTokenId] = Child({
            name: _name,
            dateOfBirth: _dateOfBirth,
            parentName: _parentName,
            contactInfo: _contactInfo,
            parentAddress: _parentAddress,
            registeredByHospital: msg.sender,
            hospitalName: hospitals[msg.sender].name,
            isRegistered: true,
            registrationDate: block.timestamp
        });
        
        tokenURIs[newTokenId] = _tokenURI;
        parentToChildren[_parentAddress].push(newTokenId);
        
        emit ChildRegistered(newTokenId, _name, _parentAddress, msg.sender);
        return newTokenId;
    }
    
    // Enhanced vaccination recording with QR code generation
    function recordVaccination(
        uint256 _tokenId,
        string memory _vaccineName,
        string memory _batchNumber,
        uint256 _nextDueDate,
        string memory _ipfsHash
    ) public onlyAuthorizedHospital {
        require(_exists(_tokenId), "Token does not exist");
        
        // Generate QR code hash (combination of token ID, vaccination, and timestamp)
        string memory qrCodeHash = generateQRCodeHash(_tokenId, _vaccineName, block.timestamp);
        
        VaccinationRecord memory newRecord = VaccinationRecord({
            vaccineName: _vaccineName,
            dateAdministered: block.timestamp,
            hospitalName: hospitals[msg.sender].name,
            administeredBy: msg.sender,
            batchNumber: _batchNumber,
            nextDueDate: _nextDueDate,
            isVerified: true,
            ipfsHash: _ipfsHash,
            qrCodeHash: qrCodeHash
        });
        
        vaccinationHistory[_tokenId].push(newRecord);
        
        // Add reminder if next dose is due
        if (_nextDueDate > block.timestamp) {
            vaccinationReminders[_tokenId].push(_nextDueDate);
            emit ReminderTriggered(_tokenId, _vaccineName, _nextDueDate);
        }
        
        emit VaccinationRecorded(_tokenId, _vaccineName, block.timestamp, qrCodeHash);
        emit QRCodeGenerated(_tokenId, vaccinationHistory[_tokenId].length - 1, qrCodeHash);
    }
    
    // Generate unique QR code hash
    function generateQRCodeHash(uint256 _tokenId, string memory _vaccineName, uint256 _timestamp) 
        internal pure returns (string memory) {
        return string(abi.encodePacked(
            "QR",
            Strings.toString(_tokenId),
            "_",
            _vaccineName,
            "_",
            Strings.toString(_timestamp)
        ));
    }
    
    // Get all children for a parent
    function getParentChildren(address _parent) public view returns (uint256[] memory) {
        return parentToChildren[_parent];
    }
    
    // Get vaccination reminders for a child
    function getVaccinationReminders(uint256 _tokenId) public view returns (uint256[] memory) {
        require(_exists(_tokenId), "Token does not exist");
        return vaccinationReminders[_tokenId];
    }
    
    // Get upcoming vaccinations (within next 30 days)
    function getUpcomingVaccinations(uint256 _tokenId) public view returns (
        string[] memory vaccineNames,
        uint256[] memory dueDates
    ) {
        require(_exists(_tokenId), "Token does not exist");
        
        uint256[] memory reminders = vaccinationReminders[_tokenId];
        uint256 upcomingCount = 0;
        
        // Count upcoming vaccinations
        for (uint i = 0; i < reminders.length; i++) {
            if (reminders[i] > block.timestamp && reminders[i] <= block.timestamp + 30 days) {
                upcomingCount++;
            }
        }
        
        vaccineNames = new string[](upcomingCount);
        dueDates = new uint256[](upcomingCount);
        
        uint256 currentIndex = 0;
        VaccinationRecord[] memory records = vaccinationHistory[_tokenId];
        
        for (uint i = 0; i < records.length; i++) {
            if (records[i].nextDueDate > block.timestamp && 
                records[i].nextDueDate <= block.timestamp + 30 days) {
                vaccineNames[currentIndex] = records[i].vaccineName;
                dueDates[currentIndex] = records[i].nextDueDate;
                currentIndex++;
            }
        }
    }
    
    // Enhanced verification data with QR support
    function generateVerificationQR(uint256 _tokenId) public view returns (
        string memory qrData,
        string memory childName,
        uint256 totalVaccinations,
        bool isUpToDate
    ) {
        require(_exists(_tokenId), "Token does not exist");
        
        Child memory child = children[_tokenId];
        VaccinationRecord[] memory records = vaccinationHistory[_tokenId];
        
        childName = child.name;
        totalVaccinations = records.length;
        
        uint256 ageInDays = (block.timestamp - child.dateOfBirth) / 86400;
        uint256 expectedVaccinations = getExpectedVaccinationCount(ageInDays);
        isUpToDate = totalVaccinations >= expectedVaccinations;
        
        // Generate QR data with verification info
        qrData = string(abi.encodePacked(
            "CHILD_ID:", Strings.toString(_tokenId),
            "|NAME:", childName,
            "|VACCINES:", Strings.toString(totalVaccinations),
            "|STATUS:", isUpToDate ? "UP_TO_DATE" : "PENDING",
            "|VERIFIED:", Strings.toString(block.timestamp)
        ));
    }
    
    // Hospital authorization (only owner can authorize)
    function setHospitalAuthorization(address _hospital, bool _authorized) public onlyOwner {
        require(hospitals[_hospital].registrationDate > 0, "Hospital not registered");
        authorizedHospitals[_hospital] = _authorized;
        hospitals[_hospital].isAuthorized = _authorized;
        emit HospitalAuthorized(_hospital, _authorized);
    }
    
    // Get hospital info
    function getHospitalInfo(address _hospital) public view returns (Hospital memory) {
        return hospitals[_hospital];
    }
    
    function getChildInfo(uint256 _tokenId) public view returns (Child memory) {
        require(_exists(_tokenId), "Token does not exist");
        return children[_tokenId];
    }
    
    function getVaccinationHistory(uint256 _tokenId) public view returns (VaccinationRecord[] memory) {
        require(_exists(_tokenId), "Token does not exist");
        return vaccinationHistory[_tokenId];
    }
    
    function getVaccinationCount(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "Token does not exist");
        return vaccinationHistory[_tokenId].length;
    }
    
    function hasVaccine(uint256 _tokenId, string memory _vaccineName) public view returns (bool) {
        require(_exists(_tokenId), "Token does not exist");
        VaccinationRecord[] memory records = vaccinationHistory[_tokenId];
        
        for (uint i = 0; i < records.length; i++) {
            if (keccak256(bytes(records[i].vaccineName)) == keccak256(bytes(_vaccineName))) {
                return true;
            }
        }
        return false;
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return tokenURIs[tokenId];
    }
    
    // Prevent transfers (soulbound)
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        require(from == address(0) || to == address(0), "Soulbound: Transfer not allowed");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function getExpectedVaccinationCount(uint256 ageInDays) private pure returns (uint256) {
        if (ageInDays < 42) return 3;      // 0-6 weeks
        if (ageInDays < 84) return 6;      // 6-12 weeks  
        if (ageInDays < 126) return 9;     // 12-18 weeks
        if (ageInDays < 365) return 12;    // 18 weeks - 1 year
        if (ageInDays < 730) return 15;    // 1-2 years
        return 18;                         // 2+ years
    }
    
    // Allow parents to update their contact info
    function updateChildInfo(
        uint256 _tokenId,
        string memory _contactInfo
    ) public onlyTokenOwner(_tokenId) {
        children[_tokenId].contactInfo = _contactInfo;
    }
}