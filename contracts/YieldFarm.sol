// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YieldFarmSimulator is Ownable {
    IERC20 public immutable token;
    uint256 public apy; // לדוגמה: 10 עבור 10%
    uint256 public blocksPerYear; // מספר הבלוקים הצפוי בשנה

    // המבנה שישמור את נתוני ההפקדה של כל משתמש
    struct DepositInfo {
        uint256 amount;
        uint256 lastBlock;
    }

    mapping(address => DepositInfo) public deposits;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _token, uint256 _apy, uint256 _blocksPerYear) Ownable(msg.sender) {
        token = IERC20(_token);
        apy = _apy;
        blocksPerYear = _blocksPerYear;
    }

    function setApy(uint256 _newApy) external onlyOwner {
        apy = _newApy;
    }

    // הפקדה - הפונקציה המרכזית
    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        _updateUserYield(msg.sender); // עדכון ריבית לפני פעולה!

        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        deposits[msg.sender].amount += _amount;
        deposits[msg.sender].lastBlock = block.number;

        emit Deposited(msg.sender, _amount);
    }

    // משיכה - הפונקציה המרכזית
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        _updateUserYield(msg.sender); // עדכון ריבית לפני פעולה!

        require(deposits[msg.sender].amount >= _amount, "Insufficient balance");
        deposits[msg.sender].amount -= _amount;
        deposits[msg.sender].lastBlock = block.number;

        require(token.transfer(msg.sender, _amount), "Transfer failed");
        emit Withdrawn(msg.sender, _amount);
    }

    // פונקציה לצפייה ביתרה הנוכחית כולל ריבית
    function getBalance(address _user) public view returns (uint256) {
        DepositInfo memory info = deposits[_user];
        if (info.amount == 0) return 0;

        uint256 blocksPassed = block.number - info.lastBlock;
        if (blocksPassed == 0) return info.amount;

        // חישוב הריבית הדריבית לפי בלוקים
        // ratePerBlock = (APY / 100) / blocksPerYear
        uint256 ratePerBlock = (apy * 1e18) / (100 * blocksPerYear);
        uint256 compoundedAmount = info.amount;

        // לולאה המדמה את צבירת הריבית בכל בלוק (דיסקרטית)
        for (uint256 i = 0; i < blocksPassed; i++) {
            compoundedAmount = (compoundedAmount * (1e18 + ratePerBlock)) / 1e18;
        }

        return compoundedAmount;
    }

    // פונקציה פנימית לעדכון יתרת המשתמש במצב (storage)
    function _updateUserYield(address _user) internal {
        uint256 currentBalance = getBalance(_user);
        deposits[_user].amount = currentBalance;
        deposits[_user].lastBlock = block.number;
    }

    // "נקודת יציאה" אם משתמשים שולחים ETH בטעות לקונטרקט הזה
    receive() external payable {
        revert("Do not send ETH directly");
    }
}