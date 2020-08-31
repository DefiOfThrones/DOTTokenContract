pragma solidity ^0.6.2;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/IDotTokenContract.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/libs/Ownable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/libs/SafeMath.sol";



/**
 * @title TokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 */
contract DotxVesting is Ownable {

    using SafeMath for uint256;

    event TokensReleased(address token, uint256 amount);

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    uint256 private _cliff;
    uint256 private _start;
    uint256 private _duration;

    mapping (address => uint256) private _released;

    IDotTokenContract private dotxToken;
    address private tokenAddress;

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * owner, gradually in a linear fashion until start + duration. By then all
     * of the balance will have vested.
     * @param cliffDuration duration in seconds of the cliff in which tokens will begin to vest
     * @param start the time (as Unix time) at which point vesting starts
     * @param duration duration in seconds of the period in which the tokens will vest
     */
     
    constructor(address dotxTokenAddress, uint256 start, uint256 cliffDuration, uint256 duration) public {
        dotxToken = IDotTokenContract(dotxTokenAddress);
        tokenAddress = dotxTokenAddress;
        
        start = start == 0 ? now : start;

        // solhint-disable-next-line max-line-length
        require(cliffDuration <= duration, "TokenVesting: cliff is longer than duration");
        require(duration > 0, "TokenVesting: duration is 0");
        // solhint-disable-next-line max-line-length
        require(start.add(duration) > block.timestamp, "TokenVesting: final time is before current time");

        _duration = duration;
        _cliff = start.add(cliffDuration);
        _start = start;
    }


    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view returns (address) {
        return owner();
    }

    /**
     * @return the cliff time of the token vesting.
     */
    function cliff() public view returns (uint256) {
        return _cliff;
    }

    /**
     * @return the start time of the token vesting.
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @return the duration of the token vesting.
     */
    function duration() public view returns (uint256) {
        return _duration;
    }

    /**
     * @return the amount of the token released.
     */
    function released(address token) public view returns (uint256) {
        return _released[token];
    }

    /**
     * @notice Transfers vested tokens to beneficiary.
     */
    function release() public onlyOwner {
        uint256 unreleased = _releasableAmount();

        require(unreleased > 0, "TokenVesting: no tokens are due");

        _released[address(tokenAddress)] = _released[address(tokenAddress)].add(unreleased);

        dotxToken.transfer(owner(), unreleased);

        emit TokensReleased(address(tokenAddress), unreleased);
    }

    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     */
    function _releasableAmount() private view returns (uint256) {
        return vestedAmount().sub(_released[address(tokenAddress)]);
    }

    /**
     * @dev Calculates the amount that has already vested.
     */
    function vestedAmount() public view returns (uint256) {
        uint256 currentBalance = dotxToken.balanceOf(address(this));
        uint256 totalBalance = currentBalance.add(_released[address(tokenAddress)]);

        if (block.timestamp < _cliff) {
            return 0;
        } else if (block.timestamp >= _start.add(_duration)) {
            return totalBalance;
        } else {
            return totalBalance.mul(block.timestamp.sub(_start)).div(_duration);
        }
    }

}
