// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155} from "solady/tokens/ERC1155.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

struct Score {
    uint256 yoinks;
    uint256 time;
    uint256 lastYoinkedAt;
}

error SlowDown(uint256 timeRemaining);
error Unauthorized();

event Yoinked(address indexed by, address indexed from);

contract Yoink is ERC1155 {
    uint256 public totalYoinks;
    uint256 public lastYoinkedAt;
    address public lastYoinkedBy;

    mapping(address yoinker => Score score) internal _score;

    uint256 public constant COOLDOWN = 10 minutes;
    uint256 public constant FLAG_ID = 1;

    constructor() {
        lastYoinkedAt = block.timestamp;
        lastYoinkedBy = address(this);
        _mint(address(this), FLAG_ID, 1, "");
    }

    function yoink() public {
        // THE RULES OF YOINK:
        // 1. You can't yoink the flag from yourself.
        if (msg.sender == lastYoinkedBy) revert Unauthorized();

        Score storage yoinker = _score[msg.sender];

        // 2. You can only yoink the flag once every ten minutes.
        uint256 timeSinceLastYoink = block.timestamp - yoinker.lastYoinkedAt;
        if (timeSinceLastYoink < COOLDOWN) {
            revert SlowDown(COOLDOWN - timeSinceLastYoink);
        }

        // 3. When you yoink the flag, you get the Flag token.
        _safeTransfer(lastYoinkedBy, msg.sender, FLAG_ID, 1, "");

        // 4. The first time you yoink, you get a score token.
        if (yoinker.yoinks == 0) {
            _mint(msg.sender, _scoreTokenId(msg.sender), 1, "");
        }
        emit Yoinked(msg.sender, lastYoinkedBy);

        // 5. The leaderboard tracks how long you hold the flag.
        _updateTimeHeld();

        // ...how many times the flag has been yoinked,
        totalYoinks++;
        lastYoinkedAt = block.timestamp;
        lastYoinkedBy = msg.sender;

        // ...and how many times you yoinked the flag.
        yoinker.yoinks++;
        yoinker.lastYoinkedAt = block.timestamp;
    }

    function score(address yoinker) public view returns (Score memory) {
        Score memory currentScore = _score[yoinker];

        // Account for elapsed time if address is latest yoinker
        if (yoinker == lastYoinkedBy) {
            currentScore.time += block.timestamp - lastYoinkedAt;
        }

        return currentScore;
    }

    function uri(uint256 id) public view virtual override returns (string memory) {
        string memory json;
        if (id == FLAG_ID) {
            address holder = lastYoinkedBy;
            Score memory holderScore = score(holder);
            json = generateFlagJSON(holder, holderScore);
        } else {
            address tokenHolder = address(uint160(id));
            Score memory holderScore = score(tokenHolder);
            json = generateScoreJSON(tokenHolder, holderScore);
        }
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    function generateFlagJSON(address holder, Score memory holderScore)
        public
        pure
        returns (string memory)
    {
        return string.concat(
            '{"name": "The Flag", "description": "Click to yoink the flag.", ',
            '"image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(generateFlagSVG(holder, holderScore))),
            '", "attributes": [',
            '{"trait_type": "Current Holder", "value": "',
            LibString.toHexString(holder),
            '"}, {"trait_type": "Yoinks", "value": ',
            LibString.toString(holderScore.yoinks),
            '}, {"trait_type": "Total Time Held", "value": ',
            LibString.toString(holderScore.time),
            "}]}"
        );
    }

    function generateFlagSVG(address holder, Score memory holderScore)
        public
        pure
        returns (string memory)
    {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" style="background:#000">',
            "<style>.base { fill: white; font-family: monospace; font-size: 16px; }</style>",
            unicode'<text x="100" y="80" class="base">🏆 You have the flag. 🚩</text>',
            '<rect x="98" y="98" width="224" height="184" fill="#ff0000"/>',
            '<rect x="100" y="100" width="220" height="180" fill="#333"/>',
            unicode'<text x="120" y="150" class="base">👤 Yoinker:</text>',
            '<text x="120" y="170" class="base">',
            _truncateAddress(holder),
            "</text>",
            unicode'<text x="120" y="200" class="base">📊 Yoinks: ',
            LibString.toString(holderScore.yoinks),
            "</text>",
            unicode'<text x="120" y="230" class="base">⏱️ Time: ',
            LibString.toString(holderScore.time),
            "s</text>",
            "</svg>"
        );
    }

    function generateScoreJSON(address holder, Score memory holderScore)
        public
        pure
        returns (string memory)
    {
        return string.concat(
            '{"name": "Yoink Score - ',
            LibString.toHexString(holder),
            unicode'", "description": "Thank you for Yoinking! —MGMT", ',
            '"image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(generateScoreSVG(holder, holderScore))),
            '", "attributes": [',
            '{"trait_type": "Yoinks", "value": ',
            LibString.toString(holderScore.yoinks),
            '}, {"trait_type": "Total Time Held", "value": ',
            LibString.toString(holderScore.time),
            "}]}"
        );
    }

    function generateScoreSVG(address holder, Score memory holderScore)
        public
        pure
        returns (string memory)
    {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" style="background:#000">',
            "<style>.base { fill: white; font-family: monospace; font-size: 16px; }</style>",
            unicode'<text x="100" y="80" class="base">Thank you for Yoinking!</text>',
            unicode'<text x="100" y="100" class="base"> —MGMT 🚩</text>',
            '<rect x="98" y="118" width="224" height="184" fill="#ff0000"/>',
            '<rect x="100" y="120" width="220" height="180" fill="#333"/>',
            unicode'<text x="120" y="170" class="base">👤 Yoinker:</text>',
            '<text x="120" y="190" class="base">',
            _truncateAddress(holder),
            "</text>",
            unicode'<text x="120" y="220" class="base">📊 Yoinks: ',
            LibString.toString(holderScore.yoinks),
            "</text>",
            unicode'<text x="120" y="250" class="base">⏱️ Time: ',
            LibString.toString(holderScore.time),
            "s</text>",
            "</svg>"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public override {
        if (id == FLAG_ID) revert Unauthorized();
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public override {
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == FLAG_ID) revert Unauthorized();
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function _scoreTokenId(address yoinker) internal pure returns (uint256) {
        return uint256(uint160(yoinker));
    }

    function _updateTimeHeld() internal returns (uint256 timeHeld) {
        timeHeld = block.timestamp - lastYoinkedAt;
        _score[lastYoinkedBy].time += timeHeld;
    }

    function _truncateAddress(address addr) internal pure returns (string memory) {
        string memory fullAddr = LibString.toHexString(addr);
        return string.concat(
            LibString.slice(fullAddr, 0, 10), unicode"…", LibString.slice(fullAddr, 34, 42)
        );
    }
}
