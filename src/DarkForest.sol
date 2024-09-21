// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@fhenixprotocol/contracts/FHE.sol";
import "@fhenixprotocol/contracts/access/Permissioned.sol";

uint8 constant GRID_SIZE = 128;

library RandomMock {
    function getFakeRandomU8(uint256 seed) internal view returns (euint8) {
        uint256 randomValue = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed)));
        return FHE.asEuint8(uint8(randomValue % GRID_SIZE));
    }
}

library FHEHelper {
    function diffAbsEuint8(euint8 a, euint8 b) public pure returns (euint8) {
        ebool aLtB = a.lt(b);
        return FHE.select(aLtB, b - a, a - b);
    }
}

contract DarkForestFHE is Permissioned {
    using RandomMock for uint256;

    struct Spaceship {
        euint8 x;
        euint8 y;
        euint8 techLevel;
        eaddress owner;
        ebool active;
        uint256 round;
    }

    struct Planet {
        euint8 x;
        euint8 y;
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
        // Initialize spaceships at random positions
        spaceships[player1] = Spaceship({
            x: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("player1_x", player1)))),
            y: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("player1_y", player1)))),
            techLevel: FHE.asEuint8(0),
            owner: FHE.asEaddress(player1),
            active: FHE.asEbool(true),
            round: 1
        });

        spaceships[player2] = Spaceship({
            x: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("player2_x", player2)))),
            y: RandomMock.getFakeRandomU8(uint256(keccak256(abi.encodePacked("player2_y", player2)))),
            techLevel: FHE.asEuint8(0),
            owner: FHE.asEaddress(player2),
            active: FHE.asEbool(true),
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

    function move(inEuint8 calldata newX, inEuint8 calldata newY) public {
        Spaceship storage ship = spaceships[msg.sender];
        FHE.req(ship.active);

        euint8 deltaX = FHEHelper.diffAbsEuint8(FHE.asEuint8(newX), ship.x);
        euint8 deltaY = FHEHelper.diffAbsEuint8(FHE.asEuint8(newY), ship.y);
        euint8 movementRange = FHE.asEuint8(uint8(2 ** (ship.round - 1 + FHE.decrypt(ship.techLevel))));

        FHE.req(FHE.lte(FHE.add(deltaX, deltaY), movementRange));

        ship.x = FHE.asEuint8(newX);
        ship.y = FHE.asEuint8(newY);

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
            ship.techLevel = FHE.select(canClaim, FHE.add(ship.techLevel, FHE.asEuint8(1)), ship.techLevel);
        }
    }

    function checkForCombat() private {
        Spaceship storage ship1 = spaceships[player1];
        Spaceship storage ship2 = spaceships[player2];
        if (ship1.round != ship2.round) {
            return;
        }

        // Calculate distance between the two ships
        euint8 distance = FHE.add(FHEHelper.diffAbsEuint8(ship1.x, ship2.x), FHEHelper.diffAbsEuint8(ship1.y, ship2.y));

        // Determine which ship has the higher tech level
        ebool ship1HigherTech = FHE.gte(ship1.techLevel, ship2.techLevel);

        // Calculate vision range based on the higher tech level
        euint8 higherTechLevel = FHE.select(ship1HigherTech, ship1.techLevel, ship2.techLevel);
        euint8 visionRange = FHE.asEuint8(uint8(2 ** (ship1.round - 1 + FHE.decrypt(higherTechLevel))));

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
        // Deactivate both ships
        spaceships[player1].active = FHE.asEbool(false);
        spaceships[player2].active = FHE.asEbool(false);

        emit GameEnded(winner);
        // Additional end game logic can be added here
    }

    function queryVision(Permission calldata perm) public view onlySender(perm) returns (string[][] memory) {
        Spaceship storage ship = spaceships[msg.sender];
        uint8 visionRange = uint8(2 ** (ship.round - 1 + FHE.decrypt(ship.techLevel)));

        // Create an array to store visible objects
        string[][] memory visiblePlanets;

        // Check visibility of planets
        uint256 planetIndex = 0;
        for (uint256 i = 0; i < PLANETS_COUNT; i++) {
            if (isInRange(ship, planets[i], visionRange)) {
                string[] memory planetInfo = new string[](3);
                planetInfo[0] = planets[i].x.seal(perm.publicKey);
                planetInfo[1] = planets[i].y.seal(perm.publicKey);
                planetInfo[2] = FHE.asEuint8(uint8(i)).seal(perm.publicKey); // Planet index
                visiblePlanets[planetIndex] = planetInfo;
                planetIndex++;
            }
        }

        // Seal the output for the specific public key
        return visiblePlanets;
    }

    function isInRange(Spaceship storage ship, Planet storage planet, uint8 range) private view returns (bool) {
        euint8 deltaX = FHEHelper.diffAbsEuint8(ship.x, planet.x);
        euint8 deltaY = FHEHelper.diffAbsEuint8(ship.y, planet.y);
        return FHE.decrypt(FHE.lte(FHE.add(deltaX, deltaY), FHE.asEuint8(range)));
    }

    function isInRange(Spaceship storage ship1, Spaceship storage ship2, uint8 range) private view returns (bool) {
        euint8 deltaX = FHEHelper.diffAbsEuint8(ship1.x, ship2.x);
        euint8 deltaY = FHEHelper.diffAbsEuint8(ship1.y, ship2.y);
        return FHE.decrypt(FHE.lte(FHE.add(deltaX, deltaY), FHE.asEuint8(range)));
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
