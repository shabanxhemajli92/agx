// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/Ownable.sol";

contract Agronyx is ERC20, ERC20Burnable, Pausable, Ownable {
    uint256 public transferFeePercent = 2; // Default 2% fee
    address public treasury;

    uint256 public maxTxPercent = 2; // Max transfer % per tx
    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10 ** 18;

    mapping(address => bool) public isBlacklisted;

    event Blacklisted(address indexed account, bool status);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event FeeChanged(uint256 oldFee, uint256 newFee);
    event MaxTxPercentChanged(uint256 oldValue, uint256 newValue);

    constructor(address _treasury) ERC20("Agronyx", "AGX") {
        require(_treasury != address(0), "Treasury address is zero");
        treasury = _treasury;
        _mint(msg.sender, MAX_SUPPLY);
    }

    modifier notBlacklisted(address account) {
        require(!isBlacklisted[account], "Blacklisted address");
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setBlacklist(address account, bool status) public onlyOwner {
        isBlacklisted[account] = status;
        emit Blacklisted(account, status);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Zero address");
        emit TreasuryChanged(treasury, _treasury);
        treasury = _treasury;
    }

    function setFeePercent(uint256 percent) external onlyOwner {
        require(percent <= 10, "Fee too high");
        emit FeeChanged(transferFeePercent, percent);
        transferFeePercent = percent;
    }

    function setMaxTxPercent(uint256 percent) external onlyOwner {
        require(percent >= 1 && percent <= 100, "Out of range");
        emit MaxTxPercentChanged(maxTxPercent, percent);
        maxTxPercent = percent;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20)
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
    {
        super._beforeTokenTransfer(from, to, amount);

        if (from != address(0) && to != address(0) && from != owner()) {
            uint256 maxAmount = (totalSupply() * maxTxPercent) / 100;
            require(amount <= maxAmount, "Exceeds max tx limit");
        }
    }

    function _transfer(address from, address to, uint256 amount) internal override(ERC20) {
        if (from == owner() || to == owner()) {
            super._transfer(from, to, amount);
        } else {
            uint256 fee = (amount * transferFeePercent) / 100;
            uint256 amountAfterFee = amount - fee;
            super._transfer(from, treasury, fee);
            super._transfer(from, to, amountAfterFee);
        }
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
}
