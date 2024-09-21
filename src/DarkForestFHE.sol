// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@fhenixprotocol/contracts/FHE.sol";
import "@fhenixprotocol/contracts/access/Permissioned.sol";
import { console2 } from "forge-std/src/console2.sol";
import { Console } from "@fhenixprotocol/contracts/utils/debug/Console.sol";

uint128 constant GRID_SIZE = 128;

library RandomMock {
    function getFakeRandomU8(uint256 seed) internal view returns (euint128) {
        uint256 randomValue = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed)));
        return FHE.asEuint128(uint128(randomValue % GRID_SIZE));
    }
}

library FHEHelper {
    function diffAbsEuint128(euint128 a, euint128 b) public pure returns (euint128) {
        // Select the correct result
        ebool aLtB = FHE.lt(a, b);

        // Add the maximum value to both a and b to prevent underflow
        euint128 largerValue = FHE.select(aLtB, b, a);
        euint128 smallerValue = FHE.select(aLtB, a, b);

        return FHE.sub(largerValue, smallerValue);
    }
}

contract DarkForestFHE is Permissioned {
    using RandomMock for uint256;

    struct Spaceship {
        euint128 x;
        euint128 y;
        euint128 techLevel;
        address owner;
        uint256 round;
    }

    struct Planet {
        euint128 x;
        euint128 y;
        ebool claimed;
    }

    struct SealedPlannet {
        bytes x;
        bytes y;
    }

    address public player1;
    address public player2;
    mapping(address => Spaceship) public spaceships;
    uint256 public constant PLANETS_COUNT = 15;
    Planet[PLANETS_COUNT] public planets;

    event GameStarted(address player1, address player2);
    event PlanetClaimed(address player, uint256 planetIndex);
    event GameEnded(address winner);

    constructor(address player1_, address player2_) {
        player1 = player1_;
        player2 = player2_;
        initializeGame(player1_, player2_);
    }

    function initializeGame(address player1, address player2) private {
        euint128 a = RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("player1_x", player1))));

        // Initialize spaceships at random positions
        spaceships[player1] = Spaceship({
            x: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("player1_x", player1)))),
            y: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("player1_y", player1)))),
            techLevel: FHE.asEuint128(0),
            owner: player1,
            round: 1
        });

        spaceships[player2] = Spaceship({
            x: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("player2_x", player2)))),
            y: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("player2_y", player2)))),
            techLevel: FHE.asEuint128(0),
            owner: player2,
            round: 1
        });

        // Initialize planets at random positions
        for (uint256 i = 0; i < PLANETS_COUNT; i++) {
            planets[i] = Planet({
                x: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("planet_x", i)))),
                y: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("planet_y", i)))),
                claimed: FHE.asEbool(false)
            });
        }

        emit GameStarted(player1, player2);
    }

    function move(inEuint128 calldata newX, inEuint128 calldata newY) public {
        Spaceship storage ship = spaceships[msg.sender];

        euint128 deltaX = FHEHelper.diffAbsEuint128(FHE.asEuint128(newX), ship.x);
        euint128 deltaY = FHEHelper.diffAbsEuint128(FHE.asEuint128(newY), ship.y);
        euint128 movementRange = FHE.asEuint128(uint128(2 ** (ship.round - 1 + FHE.decrypt(ship.techLevel))));

        FHE.req(FHE.lte(FHE.add(deltaX, deltaY), movementRange));

        ship.x = FHE.asEuint128(newX);
        ship.y = FHE.asEuint128(newY);

        checkForPlanetClaim();
        checkForCombat();
        ship.round++;
    }

    function checkForPlanetClaim() private {
        Spaceship storage ship = spaceships[msg.sender];
        for (uint256 i = 0; i < PLANETS_COUNT; i++) {
            ebool samePosition = FHE.and(FHE.eq(ship.x, planets[i].x), FHE.eq(ship.y, planets[i].y));
            ebool canClaim = FHE.and(samePosition, FHE.not(planets[i].claimed));

            planets[i].claimed = FHE.asEbool(true);
            ship.techLevel = FHE.select(canClaim, FHE.add(ship.techLevel, FHE.asEuint128(1)), ship.techLevel);
        }
    }

    function checkForCombat() private {
        Spaceship storage ship1 = spaceships[player1];
        Spaceship storage ship2 = spaceships[player2];
        if (ship1.round != ship2.round) {
            return;
        }

        // Calculate distance between the two ships
        euint128 distance =
            FHE.add(FHEHelper.diffAbsEuint128(ship1.x, ship2.x), FHEHelper.diffAbsEuint128(ship1.y, ship2.y));

        // Determine which ship has the higher tech level
        ebool ship1HigherTech = FHE.gte(ship1.techLevel, ship2.techLevel);

        // Calculate vision range based on the higher tech level
        euint128 higherTechLevel = FHE.select(ship1HigherTech, ship1.techLevel, ship2.techLevel);
        euint128 visionRange = FHE.asEuint128(uint128(2 ** (ship1.round - 1 + FHE.decrypt(higherTechLevel))));

        // Check if ships are in range
        ebool inRange = FHE.lte(distance, visionRange);

        // Determine the winner (ship with higher tech level)
        address winner = FHE.decrypt(ship1HigherTech) ? player1 : player2;

        // If ships are in range, end the game
        if (FHE.decrypt(inRange)) {
            endGame(winner);
        }
    }

    function endGame(address winner) private {
        emit GameEnded(winner);
        // Additional end game logic can be added here
    }

    function queryVision(Permission calldata perm) public view onlySender(perm) returns (string[][] memory) {
        Spaceship storage ship = spaceships[msg.sender];
        uint128 visionRange = uint128(2 ** (ship.round - 1 + FHE.decrypt(ship.techLevel)));

        // Create an array to store visible objects
        string[][] memory visiblePlanets;

        // Check visibility of planets
        uint256 planetIndex = 0;
        for (uint256 i = 0; i < PLANETS_COUNT; i++) {
            if (isInRange(ship, planets[i], visionRange)) {
                string[] memory planetInfo = new string[](3);
                planetInfo[0] = planets[i].x.seal(perm.publicKey);
                planetInfo[1] = planets[i].y.seal(perm.publicKey);
                planetInfo[2] = FHE.asEuint128(uint128(i)).seal(perm.publicKey); // Planet index
                visiblePlanets[planetIndex] = planetInfo;
                planetIndex++;
            }
        }

        // Seal the output for the specific public key
        return visiblePlanets;
    }

    function isInRange(Spaceship storage ship, Planet storage planet, uint128 range) private view returns (bool) {
        euint128 deltaX = FHEHelper.diffAbsEuint128(ship.x, planet.x);
        euint128 deltaY = FHEHelper.diffAbsEuint128(ship.y, planet.y);
        return FHE.decrypt(FHE.lte(FHE.add(deltaX, deltaY), FHE.asEuint128(range)));
    }

    function isInRange(Spaceship storage ship1, Spaceship storage ship2, uint128 range) private view returns (bool) {
        euint128 deltaX = FHEHelper.diffAbsEuint128(ship1.x, ship2.x);
        euint128 deltaY = FHEHelper.diffAbsEuint128(ship1.y, ship2.y);
        return FHE.decrypt(FHE.lte(FHE.add(deltaX, deltaY), FHE.asEuint128(range)));
    }

    // This function allows players to get their own spaceship's data, return x and y coordinates
    function getMySpaceship(Permission calldata perm)
        public
        view
        onlySender(perm)
        returns (string memory, string memory)
    {
        Spaceship storage ship = spaceships[msg.sender];
        // return (FHE.sealoutput(ship.x, perm.publicKey), FHE.sealoutput(ship.y, perm.publicKey));
        return (ship.x.seal(perm.publicKey), ship.y.seal(perm.publicKey));
    }
}
