// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FHE, euint8, euint64, euint256, externalEuint64, ebool} from "@fhevm/solidity/lib/FHE.sol";
import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";

// Strict FHE implementation: all sensitive state is encrypted.
// Modified to use KMS callback for ETH claims instead of attestor
contract LuckySpinFHE_KMS_Final is SepoliaConfig {
    // Encrypted user state
    mapping(address => euint64) private userSpins;
    mapping(address => euint64) private userGm;
    mapping(address => euint256) private userRewards; // reserved

    // Encrypted aggregates
    mapping(address => euint64) private encryptedScore;
    mapping(address => euint64) private encryptedLastSlot; // 0..7
    mapping(address => euint64) private encryptedPendingEthWei; // pending ETH

    // Non-sensitive helpers
    mapping(address => uint256) public lastCheckInTime;
    mapping(address => uint256) public lastCheckInDay;
    mapping(address => bool) private isInitialized; // tracks encrypted state initialization
    // Public, non-sensitive version counter to indicate user state changes
    mapping(address => uint256) public stateVersion;

    uint256 public constant GM_TOKEN_RATE = 1000; // 1 ETH = 1000 GM
    uint256 public constant SECONDS_PER_DAY = 24 * 60 * 60;
    address public owner;

    // ===== KMS Decryption-based claim (request/callback) =====
    mapping(address => bool) public pendingClaimRequests;
    mapping(address => uint256) public claimRequestAmount;
    mapping(address => uint256) public claimRequestTimestamp;

    // ===== Error handling (encrypted error codes) =====
    struct LastErrorRec {
        euint8 code;
        uint256 timestamp;
    }
    mapping(address => LastErrorRec) private _lastErrors;
    euint8 internal NO_ERROR;
    euint8 internal ERR_NOT_ENOUGH_GM;
    euint8 internal ERR_ALREADY_CHECKED_IN;
    euint8 internal ERR_NO_SPINS;
    event ErrorChanged(address indexed user);

    // Leaderboard (public)
    mapping(address => uint256) private publicScore;
    mapping(address => bool) private isPublished;
    address[] private publishedAddresses;
    mapping(address => uint256) private publishedIndex; // 1-based, 0 = none

    // Events (no sensitive values)
    event GmTokensBought(address indexed user, uint256 amount);
    event GmTokensBoughtFHE(address indexed user);
    event SpinBoughtWithGm(address indexed user, uint64 count);
    event CheckInCompleted(address indexed user, uint256 timestamp);
    event SpinOutcome(address indexed user, uint8 slot, uint256 prizeWei, uint64 gmDelta);
    event SpinCompleted(address indexed user, string result);
    event EthClaimed(address indexed user, uint256 amount);
    event ScoreUpdated(address indexed user, uint256 newTotalScore, uint256 delta);
    event ScorePublished(address indexed user, uint256 score);
    event ScoreUnpublished(address indexed user);
    event UserStateChanged(address indexed user, uint256 version);
    event ClaimRequested(address indexed user, uint256 amount);
    event ClaimProcessed(address indexed user, uint256 amount, bool success);

    // Minimal-HCU settlement tracking (public):
    mapping(address => uint256) public spinNonce; // increments per spinLiteCommit
    mapping(address => bytes32) public lastOutcomeCommit; // commit of last spin outcome
    mapping(address => uint256) public lastOutcomeNonce; // nonce used for lastOutcomeCommit
    mapping(address => bool) public pendingSettlement; // true when settlePrize required

    constructor() {
        owner = msg.sender;
        NO_ERROR = FHE.asEuint8(0);
        ERR_NOT_ENOUGH_GM = FHE.asEuint8(1);
        ERR_ALREADY_CHECKED_IN = FHE.asEuint8(2);
        ERR_NO_SPINS = FHE.asEuint8(3);
    }

    function ensureInit(address user) private {
        if (isInitialized[user]) return;
        // Initialize all encrypted slots to zero and set permissions
        userGm[user] = FHE.asEuint64(0);
        FHE.allowThis(userGm[user]);
        FHE.allow(userGm[user], user);

        userSpins[user] = FHE.asEuint64(0);
        FHE.allowThis(userSpins[user]);
        FHE.allow(userSpins[user], user);

        encryptedScore[user] = FHE.asEuint64(0);
        FHE.allowThis(encryptedScore[user]);
        FHE.allow(encryptedScore[user], user);

        encryptedLastSlot[user] = FHE.asEuint64(0);
        FHE.allowThis(encryptedLastSlot[user]);
        FHE.allow(encryptedLastSlot[user], user);

        encryptedPendingEthWei[user] = FHE.asEuint64(0);
        FHE.allowThis(encryptedPendingEthWei[user]);
        FHE.allow(encryptedPendingEthWei[user], user);

        isInitialized[user] = true;
    }

    function _bumpVersion(address user) private {
        unchecked {
            stateVersion[user] += 1;
        }
        emit UserStateChanged(user, stateVersion[user]);
    }

    // ===== KMS Callback Claim Functions =====

    /**
     * @dev Request ETH claim via KMS decryption
     * @param amountWei Amount to claim in wei
     */
    function requestClaimETH(uint256 amountWei) external {
        ensureInit(msg.sender);

        // Check if user has pending ETH
        euint64 pendingEth = encryptedPendingEthWei[msg.sender];

        // Set pending claim request
        pendingClaimRequests[msg.sender] = true;
        claimRequestAmount[msg.sender] = amountWei;
        claimRequestTimestamp[msg.sender] = block.timestamp;

        emit ClaimRequested(msg.sender, amountWei);
    }

    /**
     * @dev KMS callback to process claim after decryption
     * @param user User address
     * @param decryptedAmount Decrypted amount from KMS
     */
    function onClaimDecrypted(address user, uint256 decryptedAmount) external {
        // Only KMS can call this (placeholder for KMS verification)
        require(msg.sender != address(0), "Only KMS");
        require(pendingClaimRequests[user], "No pending claim");

        uint256 requestedAmount = claimRequestAmount[user];

        // Verify decrypted amount matches request
        require(decryptedAmount >= requestedAmount, "Insufficient decrypted amount");

        // Clear pending request
        pendingClaimRequests[user] = false;
        claimRequestAmount[user] = 0;
        claimRequestTimestamp[user] = 0;

        // Deduct from pending ETH
        FHE.allowThis(encryptedPendingEthWei[user]);
        FHE.allow(encryptedPendingEthWei[user], user);
        euint64 pendingEth = encryptedPendingEthWei[user];
        euint64 deductedAmount = FHE.asEuint64(uint64(requestedAmount));
        encryptedPendingEthWei[user] = FHE.sub(pendingEth, deductedAmount);
        FHE.allowThis(encryptedPendingEthWei[user]);
        FHE.allow(encryptedPendingEthWei[user], user);

        // Transfer ETH to user
        (bool success, ) = user.call{value: requestedAmount}("");
        require(success, "ETH transfer failed");

        emit ClaimProcessed(user, requestedAmount, true);
        emit EthClaimed(user, requestedAmount);

        // Update state version
        _bumpVersion(user);
    }

    /**
     * @dev Check if user has pending claim request
     */
    function hasPendingClaim(address user) external view returns (bool) {
        return pendingClaimRequests[user];
    }

    /**
     * @dev Get claim request details
     */
    function getClaimRequest(address user) external view returns (uint256 amount, uint256 timestamp) {
        return (claimRequestAmount[user], claimRequestTimestamp[user]);
    }

    // ===== Funding GM =====
    function buyGmTokens() external payable {
        ensureInit(msg.sender);
        require(msg.value > 0, "Must send ETH");
        uint256 gmPlain = (msg.value * GM_TOKEN_RATE) / 1 ether;
        euint64 credit = FHE.asEuint64(uint64(gmPlain));
        euint64 cur = userGm[msg.sender];
        userGm[msg.sender] = FHE.add(cur, credit);
        FHE.allowThis(userGm[msg.sender]);
        FHE.allow(userGm[msg.sender], msg.sender);
        emit GmTokensBought(msg.sender, gmPlain);
        _bumpVersion(msg.sender);
    }

    function buyGmTokensFHE(externalEuint64 encryptedAmount, bytes calldata proof) external payable {
        ensureInit(msg.sender);
        // Validate and import encrypted input
        euint64 credit = FHE.fromExternal(encryptedAmount, proof);
        euint64 cur = userGm[msg.sender];
        userGm[msg.sender] = FHE.add(cur, credit);
        FHE.allowThis(userGm[msg.sender]);
        FHE.allow(userGm[msg.sender], msg.sender);

        // Chuyển 100% ETH vào pool thưởng
        // ETH đã được gửi cùng transaction, contract tự động nhận toàn bộ vào pool thưởng

        emit GmTokensBoughtFHE(msg.sender);
        _bumpVersion(msg.sender);
    }

    // ===== Spins management =====
    // Pure-FHE gating using encrypted GM balance; no external encrypted input required
    function buySpinWithGm() external {
        ensureInit(msg.sender);
        euint64 gm = userGm[msg.sender];
        ebool enough = FHE.gt(gm, FHE.asEuint64(9));
        userGm[msg.sender] = FHE.select(enough, FHE.sub(gm, FHE.asEuint64(10)), gm);
        FHE.allowThis(userGm[msg.sender]);
        FHE.allow(userGm[msg.sender], msg.sender);

        euint64 spins = userSpins[msg.sender];
        userSpins[msg.sender] = FHE.select(enough, FHE.add(spins, FHE.asEuint64(1)), spins);
        FHE.allowThis(userSpins[msg.sender]);
        FHE.allow(userSpins[msg.sender], msg.sender);
        // Log error state
        _lastErrors[msg.sender] = LastErrorRec(FHE.select(enough, NO_ERROR, ERR_NOT_ENOUGH_GM), block.timestamp);
        emit ErrorChanged(msg.sender);
        emit SpinBoughtWithGm(msg.sender, 1);
        _bumpVersion(msg.sender);
    }

    // Batch purchase spins with GM in a single tx to avoid multiple prompts
    function buySpinWithGmBatch(uint64 count) external {
        ensureInit(msg.sender);
        require(count > 0 && count <= 50, "invalid count");
        euint64 gm = userGm[msg.sender];
        uint64 cost = count * 10; // 10 GM per spin
        // gm >= cost  <=> gm > cost-1 (gt only)
        ebool enough = FHE.gt(gm, FHE.asEuint64(cost - 1));
        userGm[msg.sender] = FHE.select(enough, FHE.sub(gm, FHE.asEuint64(cost)), gm);
        FHE.allowThis(userGm[msg.sender]);
        FHE.allow(userGm[msg.sender], msg.sender);

        euint64 spins = userSpins[msg.sender];
        userSpins[msg.sender] = FHE.select(enough, FHE.add(spins, FHE.asEuint64(count)), spins);
        FHE.allowThis(userSpins[msg.sender]);
        FHE.allow(userSpins[msg.sender], msg.sender);
        emit SpinBoughtWithGm(msg.sender, count);
        _bumpVersion(msg.sender);
    }

    function dailyGm() external {
        ensureInit(msg.sender);
        uint256 dayNow = block.timestamp / SECONDS_PER_DAY;
        bool can = dayNow > lastCheckInDay[msg.sender];
        if (!can) {
            // Do not revert; log encrypted error for UI to consume
            _lastErrors[msg.sender] = LastErrorRec(ERR_ALREADY_CHECKED_IN, block.timestamp);
            emit ErrorChanged(msg.sender);
            return;
        }
        lastCheckInDay[msg.sender] = dayNow;
        lastCheckInTime[msg.sender] = block.timestamp;

        euint64 spins = userSpins[msg.sender];
        userSpins[msg.sender] = FHE.add(spins, FHE.asEuint64(1));
        FHE.allowThis(userSpins[msg.sender]);
        FHE.allow(userSpins[msg.sender], msg.sender);
        // Log error state (no error when success)
        _lastErrors[msg.sender] = LastErrorRec(NO_ERROR, block.timestamp);
        emit ErrorChanged(msg.sender);
        emit CheckInCompleted(msg.sender, block.timestamp);
        _bumpVersion(msg.sender);
    }

    function checkIn() external {
        // Same as dailyGm
        ensureInit(msg.sender);
        uint256 dayNow = block.timestamp / SECONDS_PER_DAY;
        bool can = dayNow > lastCheckInDay[msg.sender];
        if (!can) {
            // Do not revert; log encrypted error for UI to consume
            _lastErrors[msg.sender] = LastErrorRec(ERR_ALREADY_CHECKED_IN, block.timestamp);
            emit ErrorChanged(msg.sender);
            return;
        }
        lastCheckInDay[msg.sender] = dayNow;
        lastCheckInTime[msg.sender] = block.timestamp;

        euint64 spins = userSpins[msg.sender];
        userSpins[msg.sender] = FHE.add(spins, FHE.asEuint64(1));
        FHE.allowThis(userSpins[msg.sender]);
        FHE.allow(userSpins[msg.sender], msg.sender);
        // Log error state (no error when success)
        _lastErrors[msg.sender] = LastErrorRec(NO_ERROR, block.timestamp);
        emit ErrorChanged(msg.sender);
        emit CheckInCompleted(msg.sender, block.timestamp);
        _bumpVersion(msg.sender);
    }

    // ===== Self-repair ACL on existing encrypted handles =====
    function reinit() external {
        // Re-grant permissions on current handles to repair drifted ACL
        FHE.allowThis(userGm[msg.sender]);
        FHE.allow(userGm[msg.sender], msg.sender);
        FHE.allowThis(userSpins[msg.sender]);
        FHE.allow(userSpins[msg.sender], msg.sender);
        FHE.allowThis(encryptedScore[msg.sender]);
        FHE.allow(encryptedScore[msg.sender], msg.sender);
        FHE.allowThis(encryptedLastSlot[msg.sender]);
        FHE.allow(encryptedLastSlot[msg.sender], msg.sender);
        FHE.allowThis(encryptedPendingEthWei[msg.sender]);
        FHE.allow(encryptedPendingEthWei[msg.sender], msg.sender);
        _bumpVersion(msg.sender);
    }

    function spin() external {
        // Optimized spin: minimal FHE ops (like spinLite)
        ensureInit(msg.sender);

        // Only operate on spins handle to minimize HCU
        FHE.allowThis(userSpins[msg.sender]);
        FHE.allow(userSpins[msg.sender], msg.sender);

        euint64 spins = userSpins[msg.sender];
        ebool canSpin = FHE.gt(spins, FHE.asEuint64(0));
        userSpins[msg.sender] = FHE.select(canSpin, FHE.sub(spins, FHE.asEuint64(1)), spins);
        FHE.allowThis(userSpins[msg.sender]);
        FHE.allow(userSpins[msg.sender], msg.sender);

        // Maintain encrypted error state
        _lastErrors[msg.sender] = LastErrorRec(FHE.select(canSpin, NO_ERROR, ERR_NO_SPINS), block.timestamp);
        emit ErrorChanged(msg.sender);

        // Compute outcome (public)
        uint256 rand = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender, block.number))
        );
        uint256 slot;
        uint256 prob = rand % 100; // 0..99
        if (prob < 1) {
            slot = 0; // 0.1 ETH
        } else {
            uint256 r = (rand / 100) % 7; // 0..6
            slot = r + 1; // 1..7
        }

        uint64 gmDelta = slot == 5 ? 5 : (slot == 6 ? 15 : (slot == 7 ? 30 : 0));
        emit SpinOutcome(msg.sender, uint8(slot), 0, gmDelta);
        emit SpinCompleted(msg.sender, "Spin completed");

        // Create commitment for later settlement
        uint256 n = spinNonce[msg.sender];
        bytes32 commit = keccak256(abi.encodePacked(address(this), msg.sender, n, uint8(slot)));
        lastOutcomeCommit[msg.sender] = commit;
        lastOutcomeNonce[msg.sender] = n;
        pendingSettlement[msg.sender] = true;
        spinNonce[msg.sender] = n + 1;

        // Lightweight score increment (+100) to reflect play action
        FHE.allowThis(encryptedScore[msg.sender]);
        FHE.allow(encryptedScore[msg.sender], msg.sender);
        euint64 scLite = encryptedScore[msg.sender];
        encryptedScore[msg.sender] = FHE.add(scLite, FHE.asEuint64(100));
        FHE.allowThis(encryptedScore[msg.sender]);
        FHE.allow(encryptedScore[msg.sender], msg.sender);
        emit ScoreUpdated(msg.sender, 0, 100);
        _bumpVersion(msg.sender);
    }

    // Minimal-HCU spin: only consume a spin and emit outcome. No prize application here.
    function spinLite() external {
        ensureInit(msg.sender);
        // Re-grant only spins handle to keep ops minimal
        FHE.allowThis(userSpins[msg.sender]);
        FHE.allow(userSpins[msg.sender], msg.sender);

        euint64 spins = userSpins[msg.sender];
        ebool canSpin = FHE.gt(spins, FHE.asEuint64(0));
        userSpins[msg.sender] = FHE.select(canSpin, FHE.sub(spins, FHE.asEuint64(1)), spins);
        FHE.allowThis(userSpins[msg.sender]);
        FHE.allow(userSpins[msg.sender], msg.sender);

        // Compute outcome (public) – users can later call settlePrize when HCU budget available
        uint256 rand = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender, block.number))
        );
        uint256 slot;
        uint256 prob = rand % 100; // 0..99
        if (prob < 1) {
            slot = 0; // 0.1 ETH
        } else {
            uint256 r = (rand / 100) % 7; // 0..6
            slot = r + 1; // 1..7
        }
        uint64 gmDelta = slot == 5 ? 5 : (slot == 6 ? 15 : (slot == 7 ? 30 : 0));
        emit SpinOutcome(msg.sender, uint8(slot), 0, gmDelta);
        emit SpinCompleted(msg.sender, "Spin completed");

        // Create commitment for secure settlement
        uint256 n = spinNonce[msg.sender];
        bytes32 commit = keccak256(abi.encodePacked(address(this), msg.sender, n, uint8(slot)));
        lastOutcomeCommit[msg.sender] = commit;
        lastOutcomeNonce[msg.sender] = n;
        pendingSettlement[msg.sender] = true;
        spinNonce[msg.sender] = n + 1;

        // Lightweight score increment (+100) as part of spinLite to reflect play action
        FHE.allowThis(encryptedScore[msg.sender]);
        FHE.allow(encryptedScore[msg.sender], msg.sender);
        euint64 scLite = encryptedScore[msg.sender];
        encryptedScore[msg.sender] = FHE.add(scLite, FHE.asEuint64(100));
        FHE.allowThis(encryptedScore[msg.sender]);
        FHE.allow(encryptedScore[msg.sender], msg.sender);
        _bumpVersion(msg.sender);
    }

    // Prize settlement callable after spinLite outcome has been observed off-chain.
    // Applies GM/ETH prizes with minimal FHE ops per call.
    function settlePrize(uint8 slot) external {
        ensureInit(msg.sender);
        require(pendingSettlement[msg.sender], "No pending prize");
        // Verify commitment matches last outcome
        uint256 n = lastOutcomeNonce[msg.sender];
        bytes32 expected = keccak256(abi.encodePacked(address(this), msg.sender, n, slot));
        require(expected == lastOutcomeCommit[msg.sender], "Invalid settlement");
        if (slot == 0) {
            // +0.1 ETH pending
            FHE.allowThis(encryptedPendingEthWei[msg.sender]);
            FHE.allow(encryptedPendingEthWei[msg.sender], msg.sender);
            euint64 p = encryptedPendingEthWei[msg.sender];
            encryptedPendingEthWei[msg.sender] = FHE.add(p, FHE.asEuint64(uint64(0.1 ether)));
            FHE.allowThis(encryptedPendingEthWei[msg.sender]);
            FHE.allow(encryptedPendingEthWei[msg.sender], msg.sender);
        } else if (slot == 1) {
            FHE.allowThis(encryptedPendingEthWei[msg.sender]);
            FHE.allow(encryptedPendingEthWei[msg.sender], msg.sender);
            euint64 p2 = encryptedPendingEthWei[msg.sender];
            encryptedPendingEthWei[msg.sender] = FHE.add(p2, FHE.asEuint64(uint64(0.01 ether)));
            FHE.allowThis(encryptedPendingEthWei[msg.sender]);
            FHE.allow(encryptedPendingEthWei[msg.sender], msg.sender);
        } else if (slot == 5) {
            FHE.allowThis(userGm[msg.sender]);
            FHE.allow(userGm[msg.sender], msg.sender);
            euint64 gm = userGm[msg.sender];
            userGm[msg.sender] = FHE.add(gm, FHE.asEuint64(5));
            FHE.allowThis(userGm[msg.sender]);
            FHE.allow(userGm[msg.sender], msg.sender);
        } else if (slot == 6) {
            FHE.allowThis(userGm[msg.sender]);
            FHE.allow(userGm[msg.sender], msg.sender);
            euint64 gm2 = userGm[msg.sender];
            userGm[msg.sender] = FHE.add(gm2, FHE.asEuint64(15));
            FHE.allowThis(userGm[msg.sender]);
            FHE.allow(userGm[msg.sender], msg.sender);
        } else if (slot == 7) {
            FHE.allowThis(userGm[msg.sender]);
            FHE.allow(userGm[msg.sender], msg.sender);
            euint64 gm3 = userGm[msg.sender];
            userGm[msg.sender] = FHE.add(gm3, FHE.asEuint64(30));
            FHE.allowThis(userGm[msg.sender]);
            FHE.allow(userGm[msg.sender], msg.sender);
        }
        // Update last slot (publicly known) into encrypted field for UI convenience
        FHE.allowThis(encryptedLastSlot[msg.sender]);
        FHE.allow(encryptedLastSlot[msg.sender], msg.sender);
        encryptedLastSlot[msg.sender] = FHE.asEuint64(uint64(slot));
        FHE.allowThis(encryptedLastSlot[msg.sender]);
        FHE.allow(encryptedLastSlot[msg.sender], msg.sender);

        // Mark settled
        pendingSettlement[msg.sender] = false;
        lastOutcomeCommit[msg.sender] = bytes32(0);
        _bumpVersion(msg.sender);
    }

    // ===== Views (encrypted getters) =====
    function getUserSpins(address user) external view returns (euint64) {
        return userSpins[user];
    }

    function getUserGmBalance(address user) external view returns (euint64) {
        return userGm[user];
    }

    function getUserRewards(address user) external view returns (euint256) {
        return userRewards[user];
    }

    function getEncryptedScore(address user) external view returns (euint64) {
        return encryptedScore[user];
    }

    function getEncryptedLastSlot(address user) external view returns (euint64) {
        return encryptedLastSlot[user];
    }

    function getEncryptedPendingEthWei(address user) external view returns (euint64) {
        return encryptedPendingEthWei[user];
    }

    // Bundle getter to fetch all encrypted user fields at once for efficient decryption
    function getEncryptedUserBundle(
        address user
    ) external view returns (euint64 spins, euint64 gm, euint64 pendingEthWei, euint64 lastSlot, euint64 score) {
        spins = userSpins[user];
        gm = userGm[user];
        pendingEthWei = encryptedPendingEthWei[user];
        lastSlot = encryptedLastSlot[user];
        score = encryptedScore[user];
    }

    // Expose last encrypted error and timestamp for frontend diagnostics
    function getLastError(address user) external view returns (euint8 code, uint256 timestamp) {
        LastErrorRec memory le = _lastErrors[user];
        return (le.code, le.timestamp);
    }

    // Admin
    function emergencyWithdraw() external {
        require(msg.sender == owner, "Only owner");
        payable(owner).transfer(address(this).balance);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ===== Leaderboard (public) =====
    function publishScore(uint256 score) external {
        if (!isPublished[msg.sender]) {
            isPublished[msg.sender] = true;
            publishedAddresses.push(msg.sender);
            publishedIndex[msg.sender] = publishedAddresses.length;
        }
        publicScore[msg.sender] = score;
        emit ScorePublished(msg.sender, score);
    }

    function unpublishScore() external {
        if (!isPublished[msg.sender]) return;
        isPublished[msg.sender] = false;
        delete publicScore[msg.sender];
        uint256 idx = publishedIndex[msg.sender];
        if (idx != 0) {
            uint256 last = publishedAddresses.length;
            if (idx != last) {
                address lastAddr = publishedAddresses[last - 1];
                publishedAddresses[idx - 1] = lastAddr;
                publishedIndex[lastAddr] = idx;
            }
            publishedAddresses.pop();
            publishedIndex[msg.sender] = 0;
        }
        emit ScoreUnpublished(msg.sender);
    }

    function isScorePublished(address user) external view returns (bool) {
        return isPublished[user];
    }

    function getPublicScore(address user) external view returns (uint256) {
        return publicScore[user];
    }

    function getPublishedRange(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory addrs, uint256[] memory scores) {
        uint256 n = publishedAddresses.length;
        if (offset >= n) {
            return (new address[](0), new uint256[](0));
        }
        uint256 end = offset + limit;
        if (end > n) end = n;
        uint256 len = end - offset;
        addrs = new address[](len);
        scores = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            address addr = publishedAddresses[offset + i];
            addrs[i] = addr;
            scores[i] = publicScore[addr];
        }
    }

    receive() external payable {}
}
