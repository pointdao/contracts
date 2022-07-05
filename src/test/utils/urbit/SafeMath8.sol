pragma solidity 0.4.24;

library SafeMath8 {
    function mul(uint8 a, uint8 b) internal pure returns (uint8) {
        uint8 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint8 a, uint8 b) internal pure returns (uint8) {
        uint8 c = a / b;
        return c;
    }

    function sub(uint8 a, uint8 b) internal pure returns (uint8) {
        assert(b <= a);
        return a - b;
    }

    function add(uint8 a, uint8 b) internal pure returns (uint8) {
        uint8 c = a + b;
        assert(c >= a);
        return c;
    }
}
