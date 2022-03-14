// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import "./GalaxyParty.sol";
import "./GalaxyLocker.sol";
import "./PointTreasury.sol";
import "./Vesting.sol";

contract Point is ERC20, ERC20Permit, ERC20Votes, Pausable, Ownable {
    uint256 constant AMOUNT_PER_GALAXY = 1000 * 10**18;
    uint256 constant MAX_GALAXY_SUPPLY = 256 * AMOUNT_PER_GALAXY;
    uint256 constant TREASURY_AMOUNT = 10664 * 10**18;
    uint256 constant MAX_SUPPLY = MAX_GALAXY_SUPPLY + TREASURY_AMOUNT;

    GalaxyParty public galaxyParty;
    GalaxyLocker public galaxyLocker;
    bool public initialized;

    constructor() ERC20("Point", "POINT") ERC20Permit("Point") {
        _pause();
    }

    modifier onlyMinter() {
        require(_msgSender() == address(galaxyParty));
        _;
    }

    modifier onlyBurner() {
        require(_msgSender() == address(galaxyLocker));
        _;
    }

    // mint treasury supply to vesting contract, set minter (galaxyParty) and burner (galaxyLocker)
    function init(
        PointTreasury treasury,
        Vesting vesting,
        GalaxyParty _galaxyParty,
        GalaxyLocker _galaxyLocker
    ) external onlyOwner {
        require(!initialized, "init can only be called once");
        initialized = true;

        _doMint(address(vesting), TREASURY_AMOUNT);
        galaxyParty = _galaxyParty;
        galaxyLocker = _galaxyLocker;

        transferOwnership(address(treasury));
    }

    function galaxyMint(address to, uint256 amount) external onlyMinter {
        require(
            amount <= AMOUNT_PER_GALAXY,
            "GalaxyParty cannot mint more than 1000 POINT at a time"
        );
        _doMint(to, amount);
    }

    function _doMint(address to, uint256 amount) private {
        bool wasPaused = paused();
        if (wasPaused) {
            _unpause();
        }
        _mint(to, amount);
        if (wasPaused) {
            _pause();
        }
    }

    function burn(address account, uint256 amount) external onlyBurner {
        require(
            amount == AMOUNT_PER_GALAXY,
            "burn amount must be exactly 1000"
        );
        bool wasPaused = paused();
        if (wasPaused) {
            _unpause();
        }
        _burn(account, amount);
        if (wasPaused) {
            _pause();
        }
    }

    function _maxSupply() internal pure override returns (uint224) {
        return uint224(MAX_SUPPLY);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
