// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockDAI is ERC20, Ownable {
    uint256 public tokenPrice; // מחיר ב-wei לכל טוקן אחד

    constructor(uint256 _pricePerToken) ERC20("Mock DAI", "mDAI") Ownable(msg.sender) {
        tokenPrice = _pricePerToken;
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        tokenPrice = _newPrice;
    }

    // הפונקציה החשובה: payable כדי לקבל ETH
    function faucet(uint256 amount) external payable {
        require(msg.value >= amount * tokenPrice, "Not enough ETH sent");
        _mint(msg.sender, amount);

        // מחזיר עודף למשתמש אם שילם יותר מדי (Best Practice)
        if (msg.value > amount * tokenPrice) {
            payable(msg.sender).transfer(msg.value - (amount * tokenPrice));
        }
    }

    // owner יכול למשוך את כל ה-ETH שנצבר בקונטרקט
    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}