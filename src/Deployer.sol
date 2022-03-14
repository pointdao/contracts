// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./GalaxyLocker.sol";
import "./GalaxyParty.sol";
import "./Point.sol";
import "./PointGovernor.sol";
import "./PointTreasury.sol";
import "./Vesting.sol";

/* Deploys entire protocol atomically */
contract Deployer {
    GalaxyLocker public galaxyLocker;
    GalaxyParty public galaxyParty;
    Point public pointToken;
    PointGovernor public pointGovernor;
    PointTreasury public pointTreasury;
    Vesting public vesting;

    constructor(
        address azimuth,
        address multisig,
        address weth
    ) {
        // token
        pointToken = new Point();

        // deploy governance
        address[] memory empty = new address[](0);
        pointTreasury = new PointTreasury(86400, empty, empty, weth);
        pointGovernor = new PointGovernor(pointToken, pointTreasury);

        // governor can propose, execute and cancel proposals
        pointTreasury.grantRole(
            pointTreasury.PROPOSER_ROLE(),
            address(pointGovernor)
        );
        pointTreasury.grantRole(
            pointTreasury.EXECUTOR_ROLE(),
            address(pointGovernor)
        );
        pointTreasury.grantRole(
            pointTreasury.CANCELLER_ROLE(),
            address(pointGovernor)
        );

        // multisig can cancel proposals and grant/revoke roles
        pointTreasury.grantRole(
            pointTreasury.CANCELLER_ROLE(),
            address(multisig)
        );
        pointTreasury.grantRole(
            pointTreasury.TIMELOCK_ADMIN_ROLE(),
            address(multisig)
        );

        // revoke unnecessary admin roles
        pointTreasury.revokeRole(
            pointTreasury.TIMELOCK_ADMIN_ROLE(),
            address(pointTreasury)
        );
        pointTreasury.revokeRole(
            pointTreasury.TIMELOCK_ADMIN_ROLE(),
            address(this)
        );

        // deployer galaxy managers (point minter and burner)
        galaxyLocker = new GalaxyLocker(
            pointToken,
            azimuth,
            address(pointTreasury)
        );
        galaxyParty = new GalaxyParty(
            azimuth,
            multisig,
            pointToken,
            galaxyLocker,
            payable(address(pointTreasury))
        );

        // initialize token
        vesting = new Vesting(pointTreasury);
        pointToken.init(pointTreasury, vesting, galaxyParty, galaxyLocker);
    }
}
