// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Yoink} from "../src/Yoink.sol";

contract Deploy is Script {
    Yoink public yoink;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        yoink = new Yoink();
        console.log("Yoink:", address(yoink));

        vm.stopBroadcast();
    }
}
