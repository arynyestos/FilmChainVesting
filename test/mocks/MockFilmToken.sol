// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MockFilmToken is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    uint256 maxSupply = 10000000042 * 10 ** decimals();

    constructor(address initialOwner) ERC20("FILM Chain", "FILM") Ownable() ERC20Permit("FILM Chain") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
        require(totalSupply() <= maxSupply, "Total supply cannot exceed maximum supply");
    }
}
