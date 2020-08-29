pragma solidity ^0.6.0;

abstract contract ERC1132 {
    mapping(address => bytes32[]) public lockReason;

    struct lockToken {
        uint256 amount;
        uint256 validity;
        bool claimed;
    }

    mapping(address => mapping(bytes32 => lockToken)) public locked;

    event Locked(
        address indexed _of,
        bytes32 indexed _reason,
        uint256 _amount,
        uint256 _validity
    );

    event Unlocked(
        address indexed _of,
        bytes32 indexed _reason,
        uint256 _amount
    );
    
    function lock(string memory _reason, uint256 _amount, uint256 _time)
        public virtual returns (bool);
  
    function tokensLocked(address _of, string memory _reason)
        public virtual view returns (uint256 amount);
    
    function tokensLockedAtTime(address _of, string memory _reason, uint256 _time)
        public virtual view returns (uint256 amount);
    
    function totalBalanceOf(address _of)
        public virtual view returns (uint256 amount);
    
    function extendLock(string memory _reason, uint256 _time)
        public virtual returns (bool);
    
    function increaseLockAmount(string memory _reason, uint256 _amount)
        public virtual returns (bool);

    function tokensUnlockable(address _of, string memory _reason)
        public virtual view returns (uint256 amount);
 
    function unlock(address _of)
        public virtual returns (uint256 unlockableTokens);

    function getUnlockableTokens(address _of)
        public virtual view returns (uint256 unlockableTokens);

}