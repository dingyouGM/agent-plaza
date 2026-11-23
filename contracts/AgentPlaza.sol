// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface of the SPACE ID Agent ID contract on BNB Chain
///         (0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F). Each holder owns one
///         soulbound ".ai" name; balanceOf > 0 means the address holds one,
///         and handleOf returns its handle (e.g. "887" for 887.ai).
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
    function handleOf(address owner) external view returns (string memory);
}

/// @title AgentPlaza — a plaza where only Agent ID holders can speak.
/// @notice Posting and liking are gated by holding an Agent ID (.ai name).
///         On their first post, each member is minted a soulbound
///         "Agent Passport" NFT whose metadata reflects their live activity
///         in the plaza (posts, likes received, member since).
/// @dev Owner permissions: NONE. This contract has no owner and no admin
///      functions; nothing can be changed, paused or withdrawn after
///      deployment. The Agent ID contract address is immutable.
///      This contract never takes custody of user assets: posting and
///      liking move no funds and request no token approvals.
contract AgentPlaza {
    // ---------------- Agent ID gate ----------------
    IAgentID public immutable agentID;

    // ---------------- Posts ----------------
    struct Post {
        address author;
        uint64 timestamp;
        uint32 likes;
        string content;
    }

    uint256 public constant MAX_CONTENT_BYTES = 500;
    uint256 public constant POST_COOLDOWN = 30 seconds;

    Post[] private _posts;
    mapping(uint256 => mapping(address => bool)) public hasLiked;
    mapping(address => uint256) public postsOf;
    mapping(address => uint256) public likesReceivedOf;
    mapping(address => uint256) public likesGivenOf;
    mapping(address => uint256) public lastPostAt;

    // ---------------- Passport (soulbound ERC-721) ----------------
    string public constant name = "Agent Passport";
    string public constant symbol = "APASS";
    uint256 private _passportSeq;
    /// @notice owner => passport tokenId (0 = none yet)
    mapping(address => uint256) public passportOf;
    mapping(uint256 => address) private _passportOwner;
    mapping(uint256 => uint64) public passportMintedAt;

    // ---------------- Events ----------------
    event PostCreated(uint256 indexed postId, address indexed author, string content, uint64 timestamp);
    event PostLiked(uint256 indexed postId, address indexed liker, address indexed author);
    /// @dev ERC-721 Transfer event, emitted only on passport mint (from = 0).
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor(address agentID_) {
        require(agentID_ != address(0), "zero address");
        agentID = IAgentID(agentID_);
    }

    modifier onlyAgent() {
        require(agentID.balanceOf(msg.sender) > 0, "Agent ID required");
        _;
    }

    // ---------------- Writing ----------------

    /// @notice Publish a post. Caller must hold an Agent ID.
    ///         The first post also mints the caller's Agent Passport.
    function post(string calldata content) external onlyAgent returns (uint256 postId) {
        uint256 len = bytes(content).length;
        require(len > 0, "empty post");
        require(len <= MAX_CONTENT_BYTES, "post too long");
        uint256 last = lastPostAt[msg.sender];
        require(last == 0 || block.timestamp >= last + POST_COOLDOWN, "cooldown");
        lastPostAt[msg.sender] = block.timestamp;

        postId = _posts.length;
        _posts.push(Post({author: msg.sender, timestamp: uint64(block.timestamp), likes: 0, content: content}));
        postsOf[msg.sender] += 1;
        emit PostCreated(postId, msg.sender, content, uint64(block.timestamp));

        if (passportOf[msg.sender] == 0) {
            _mintPassport(msg.sender);
        }
    }

    /// @notice Like a post. Caller must hold an Agent ID; one like per member per post.
    function like(uint256 postId) external onlyAgent {
        require(postId < _posts.length, "no such post");
        require(!hasLiked[postId][msg.sender], "already liked");
        hasLiked[postId][msg.sender] = true;
        Post storage p = _posts[postId];
        p.likes += 1;
        likesGivenOf[msg.sender] += 1;
        likesReceivedOf[p.author] += 1;
        emit PostLiked(postId, msg.sender, p.author);
    }

    // ---------------- Reading ----------------

    function postCount() external view returns (uint256) {
        return _posts.length;
    }

    function getPost(uint256 postId)
        external
        view
        returns (address author, string memory content, uint64 timestamp, uint32 likes, string memory handle)
    {
        require(postId < _posts.length, "no such post");
        Post storage p = _posts[postId];
        return (p.author, p.content, p.timestamp, p.likes, agentID.handleOf(p.author));
    }

    /// @notice Newest-first page of posts for the wall UI.
    function getPosts(uint256 offset, uint256 limit)
        external
        view
        returns (
            uint256[] memory ids,
            address[] memory authors,
            string[] memory contents,
            uint64[] memory timestamps,
            uint32[] memory likeCounts,
            string[] memory handles
        )
    {
        uint256 total = _posts.length;
        if (offset >= total || limit == 0) {
            return (new uint256[](0), new address[](0), new string[](0), new uint64[](0), new uint32[](0), new string[](0));
        }
        uint256 count = total - offset;
        if (count > limit) count = limit;
        ids = new uint256[](count);
        authors = new address[](count);
        contents = new string[](count);
        timestamps = new uint64[](count);
        likeCounts = new uint32[](count);
        handles = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            uint256 idx = total - 1 - offset - i;
            Post storage p = _posts[idx];
            ids[i] = idx;
            authors[i] = p.author;
            contents[i] = p.content;
            timestamps[i] = p.timestamp;
            likeCounts[i] = p.likes;
            handles[i] = agentID.handleOf(p.author);
        }
    }

    // ---------------- Passport: ERC-721 (soulbound) ----------------

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "zero address");
        return passportOf[owner] == 0 ? 0 : 1;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address o = _passportOwner[tokenId];
        require(o != address(0), "nonexistent token");
        return o;
    }

    function totalPassports() external view returns (uint256) {
        return _passportSeq;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x80ac58cd // ERC721
            || interfaceId == 0x5b5e139f // ERC721Metadata
            || interfaceId == 0x01ffc9a7; // ERC165
    }

    // Soulbound: every transfer/approval path reverts.
    function transferFrom(address, address, uint256) external pure {
        revert("soulbound");
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert("soulbound");
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert("soulbound");
    }

    function approve(address, uint256) external pure {
        revert("soulbound");
    }

    function setApprovalForAll(address, bool) external pure {
        revert("soulbound");
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        address owner = ownerOf(tokenId);
        string memory handle = agentID.handleOf(owner);
        string memory json = string(
            abi.encodePacked(
                '{"name":"Agent Passport #',
                _toString(tokenId),
                '","description":"Soulbound passport of ',
                handle,
                '.ai in Agent Plaza - a plaza where only Agent ID holders can speak.",',
                '"attributes":[',
                '{"trait_type":"Agent ID","value":"',
                handle,
                '.ai"},',
                '{"trait_type":"Posts","value":',
                _toString(postsOf[owner]),
                "},",
                '{"trait_type":"Likes Received","value":',
                _toString(likesReceivedOf[owner]),
                "},",
                '{"trait_type":"Member Since","value":',
                _toString(passportMintedAt[tokenId]),
                "}]}"
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", _base64(bytes(json))));
    }

    function _mintPassport(address to) internal {
        uint256 tokenId = ++_passportSeq;
        passportOf[to] = tokenId;
        _passportOwner[tokenId] = to;
        passportMintedAt[tokenId] = uint64(block.timestamp);
        emit Transfer(address(0), to, tokenId);
    }

    // ---------------- Helpers ----------------

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /// @dev Base64 encoding (implementation follows OpenZeppelin's Base64, MIT).
    function _base64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";
        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        string memory result = new string(encodedLen + 32);
        /// @solidity memory-safe-assembly
        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)
            let dataPtr := data
            let endPtr := add(data, mload(data))
            for {} lt(dataPtr, endPtr) {} {
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 { mstore8(sub(resultPtr, 1), 0x3d) }
            mstore(result, encodedLen)
        }
        return result;
    }
}
