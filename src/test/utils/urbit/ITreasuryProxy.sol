pragma solidity 0.4.24;

interface ITreasuryProxy {
    function upgradeTo(address _impl) external returns (bool);

    function freeze() external returns (bool);
}
