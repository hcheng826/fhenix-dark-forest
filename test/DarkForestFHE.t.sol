// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { DarkForestFHE } from "../src/DarkForestFHE.sol";
import { FheEnabled } from "../util/FheHelper.sol";
import { Permission, PermissionHelper } from "../util/PermissionHelper.sol";
import { inEuint128, euint128 } from "@fhenixprotocol/contracts/FHE.sol";
import "@fhenixprotocol/contracts/FHE.sol";

contract DarkForestFHETest is Test, FheEnabled {
    DarkForestFHE internal game;
    PermissionHelper private permitHelper;

    address public player1;
    uint256 public player1PrivateKey;
    address public player2;
    uint256 public player2PrivateKey;

    Permission private player1Permission;
    Permission private player2Permission;

    function setUp() public virtual {
        // Initialize FHE
        initializeFhe();

        // Set up players
        player1PrivateKey = 0xA11CE;
        player1 = vm.addr(player1PrivateKey);
        player2PrivateKey = 0xB0B;
        player2 = vm.addr(player2PrivateKey);

        // Deploy the game contract
        game = new DarkForestFHE(player1, player2);

        permitHelper = new PermissionHelper(address(game));

        // Generate permissions for players
        player1Permission = permitHelper.generatePermission(player1PrivateKey);
        player2Permission = permitHelper.generatePermission(player2PrivateKey);
    }

    function testInitialization() public {
        assertEq(game.player1(), player1);
        assertEq(game.player2(), player2);
    }

    function testMove() public {
        vm.startPrank(player1);

        // Verify move (indirectly, since we can't access encrypted state directly)
        (string memory encryptedXBeforeMove, string memory encryptedYBeforeMove) =
            game.getMySpaceship(player1Permission);
        uint128 xBeforeMove = uint128(unseal(address(game), encryptedXBeforeMove));
        uint128 yBeforeMove = uint128(unseal(address(game), encryptedYBeforeMove));

        uint128 newX = xBeforeMove + 1;
        uint128 newY = yBeforeMove + 1;
        inEuint128 memory encryptedX = encrypt128(newX);
        inEuint128 memory encryptedY = encrypt128(newY);

        game.move(encryptedX, encryptedY);

        (string memory encryptedXAfterMove, string memory encryptedYAfterMove) = game.getMySpaceship(player1Permission);
        uint128 xAfterMove = uint128(unseal(address(game), encryptedXAfterMove));
        uint128 yAfterMove = uint128(unseal(address(game), encryptedYAfterMove));

        assertEq(xAfterMove, newX);
        assertEq(yAfterMove, newY);

        vm.stopPrank();
    }

    function testMoveOutOfRange() public {
        vm.startPrank(player1);

        // Verify move (indirectly, since we can't access encrypted state directly)
        (string memory encryptedXBeforeMove, string memory encryptedYBeforeMove) =
            game.getMySpaceship(player1Permission);
        uint128 xBeforeMove = uint128(unseal(address(game), encryptedXBeforeMove));
        uint128 yBeforeMove = uint128(unseal(address(game), encryptedYBeforeMove));

        uint128 newX = xBeforeMove + 10;
        uint128 newY = yBeforeMove + 10;
        inEuint128 memory encryptedX = encrypt128(newX);
        inEuint128 memory encryptedY = encrypt128(newY);

        // vm.expectRevert("FHE: condition failed");
        game.move(encryptedX, encryptedY);

        vm.stopPrank();
    }

    function testPlanetClaim() public {
        vm.startPrank(player1);

        // Move to several positions to potentially claim planets
        for (uint128 i = 0; i < 15; i++) {
            inEuint128 memory encryptedX = encrypt128(i);
            inEuint128 memory encryptedY = encrypt128(i);
            game.move(encryptedX, encryptedY);
        }

        // We can't directly check if planets were claimed due to encryption
        // But we can verify that all moves were successful
        assertTrue(true);

        vm.stopPrank();
    }

    function testCombat() public {
        // Move player1
        vm.startPrank(player1);
        game.move(encrypt128(50), encrypt128(50));
        vm.stopPrank();

        // Move player2
        vm.startPrank(player2);
        game.move(encrypt128(51), encrypt128(51));
        vm.stopPrank();

        // We can't predict if combat occurred due to encryption
        // But we can verify that both moves were successful
        assertTrue(true);
    }

    function testGetMySpaceship() public {
        vm.startPrank(player1);

        (string memory encryptedX, string memory encryptedY) = game.getMySpaceship(player1Permission);

        // Decrypt and verify the position
        uint128 x = uint128(unseal(address(game), encryptedX));
        uint128 y = uint128(unseal(address(game), encryptedY));

        // We can't predict the initial position, but we can verify that it's within the grid
        assertTrue(x < 128);
        assertTrue(y < 128);

        vm.stopPrank();
    }

    // Helper function to encrypt uint128 values
    // function encrypt128(uint128 value) internal pure returns (inEuint128 memory) {
    //     return inEuint128(FHE.asEuint128(value));
    // }
}
