// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title DexiFi Bridge
 * @notice A cross-chain asset bridge that locks tokens on the source chain
 *         and mints wrapped tokens on the destination chain. For reverse transfers,
 *         wrapped tokens are burned to unlock locked original assets.
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from,address to,uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract DexiFiBridge {
    address public owner;

    struct LockRecord {
        address token;
        address user;
        uint256 amount;
        uint256 timestamp;
        bool processed;
    }

    mapping(uint256 => LockRecord) public lockRecords;
    uint256 public lockId;

    event Locked(uint256 indexed lockId, address indexed user, address token, uint256 amount);
    event Minted(address indexed user, address token, uint256 amount);
    event Burned(address indexed user, address token, uint256 amount);
    event Unlocked(address indexed user, address token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Admin only");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Source chain: lock original tokens before bridging
     */
    function lockTokens(address token, uint256 amount) external {
        require(amount > 0, "Amount > 0 required");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        lockId++;
        lockRecords[lockId] = LockRecord(
            token,
            msg.sender,
            amount,
            block.timestamp,
            false
        );

        emit Locked(lockId, msg.sender, token, amount);
    }

    /**
     * @notice Destination chain: admin mints wrapped tokens equivalent to locked originals
     */
    function mintWrapped(address wrappedToken, address user, uint256 amount) external onlyOwner {
        IERC20(wrappedToken).mint(user, amount);
        emit Minted(user, wrappedToken, amount);
    }

    /**
     * @notice Destination chain: users burn wrapped to request unlock on source chain
     */
    function burnWrapped(address wrappedToken, uint256 amount) external {
        IERC20(wrappedToken).burn(msg.sender, amount);
        emit Burned(msg.sender, wrappedToken, amount);
    }

    /**
     * @notice Source chain: admin unlocks locked originals after receiving burn proof
     */
    function unlockOriginal(uint256 _lockId, address user) external onlyOwner {
        LockRecord storage record = lockRecords[_lockId];
        require(!record.processed, "Already unlocked");

        record.processed = true;
        IERC20(record.token).transfer(user, record.amount);

        emit Unlocked(user, record.token, record.amount);
    }

    /**
     * @notice View lock record
     */
    function getLockRecord(uint256 _id) external view returns (LockRecord memory) {
        return lockRecords[_id];
    }
}
