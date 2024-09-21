# Dark Forest FHE

## Foreword
- For this submission I am mostly focusing on smart contract development as I encounter quite some trictions while trying to set up the frontend for Fhenix. Including minor flaws in provided templates, difficuties on downloading the docker container for the node to run locally due to slow network at the venue.
- This project is inspired by the game Dark Forest: https://zkga.me/. It's a game originated from the concept "Dark Forest" in science fiction "3 Body". Where in the universe the civilizations in the space try to hide their activities and traces while advancing their techinology.
- It could be a perfect use case for illustrating the concept of FHE. Using FHE we can create a decentralized setup for this game. When the spaceships travel in the space, the smart contract could compute the movement of the spaceship, without revealing it's exact location, which is exactly what FHE does.

## Gameplay

Here's a very simplified version of the game design for the course of hackathon.

1. Setup
The galactic battlefield is initialized on a 128 x 128 grid, representing the vast expanse of a war-torn sector of the universe.
- Random Placements: Two advanced spaceships, each controlled by rival alien civilizations, are deployed at random coordinates. These two flagships, piloted by your civilization's finest, are tasked with conquering 10 planets scattered across the starfield. Ensure no overlap or close proximity between spaceships and planets to give each faction a fighting chance.

2. Movement and Vision
The mobility and vision of a spaceship grow exponentially as its technology advances. A spaceship evolves by extracting resources from planets, improving its capability to explore and conquer.
- Tech Advancement: At round N, a spaceship that has colonized M planets can move and see within a range where ΔX + ΔY < 2^(N-1 + M). This growing ability represents the technological leap required to thrive in a hostile, unknown universe.
- Detection: To detect nearby objects (other spaceships or unclaimed planets), the player must query the smart contract. If the objects fall within their visible range, their coordinates and types are decrypted and revealed. This vision simulates the ever-expanding scanning field of a ship in a cosmic battlefield, equipped with long-range sensors powered by quantum decryption algorithms.

3. Combat and Endgame
In this alien war for domination, the strength of a civilization is measured by its reach.
- Combat: Spaceships with greater technological prowess (i.e., a wider vision range) automatically win battles when they encounter enemy ships. In cases where both have equal vision, the clash results in a stalemate, symbolizing an evenly matched technological race, leading to an intense battle of attrition.
- Endgame: Victory is declared when one civilization's flagship prevails in battle, establishing dominance over the starfield. Alternative endgames could be introduced later, such as controlling a majority of planets or reaching a certain tech level.

## Future Expansion
- Additional Flagships: Future versions could include multiple spaceships per civilization, introducing the concept of coordinated fleets and multi-front galactic warfare.
- Planetary Resources: Planets could yield unique resources, such as ancient alien artifacts or energy-rich minerals, with varying effects on spaceship advancement and combat capabilities.
- Planet trace: player can see the planet is landed by other players before

## Findings, feedback during the developments
Wanted to include this section to provide some feedbacks and nuances in terms of developer experience, as I believe it is quote a part of the purpose for sponsoring the hackathon

1. All the frontend examples, templates don't seem to work directly. I tried the [hardhat-template](https://github.com/FhenixProtocol/fhenix-hardhat-example), and the examples of FHERC-20 and Blind auction found [here](https://docs.fhenix.zone/docs/devdocs/Examples%20and%20References/Examples-fheDapps). The live hosted demo page couldn't successfully trigger my wallet pop-up and connect to the site. Some error in detecting the wallet, and also error while adding the network to MetaMask, the network ID returned from the rpc endpoint is not consistent to the one proposed by the frontend site.

2. Understand the support for Foundry is WIP. Sharing some naunces I discovered along my development experience.
  - The `decrypt()` function always decrypt to `0` for `euint8`. I changed it to `euint238` and it could successfully decrypt to correct value
  - A useful helper function for `euint*` operation is `absDiff()`. I tried to implemented it myself and this doesn't work:
  ```Solidity
  function absDiff(euint128 a, euint128 b) public pure returns (euint128) {
        // Select the correct result
        ebool aLtB = FHE.lt(a, b);
        return FHE.select(aLtB, b - a, a - b)
    }
  ```
  Since both branches will be computed and underflow will always happen for either of the branch. Need to manually assign the larger and smaller value and substract from there.
  ```Solidity
  function absDiff(euint128 a, euint128 b) public pure returns (euint128) {
        // Select the correct result
        ebool aLtB = FHE.lt(a, b);

        // Add the maximum value to both a and b to prevent underflow
        euint128 largerValue = FHE.select(aLtB, b, a);
        euint128 smallerValue = FHE.select(aLtB, a, b);

        return FHE.sub(largerValue, smallerValue);
  }
  ```
  - `FHE.req()` couldn't revert correctly. Not sure if it's Foundry specific issue. The below doesn't revert.
  ```Solidity
  function reqTest() public {
      FHE.req(FHE.asEbool(false));
  }
  ```
  reference: [here](https://github.com/hcheng826/fhenix-dark-forest/blob/e10065f72351c8d1c65881395ed42046abfabf0f/src/DarkForestFHE.sol#L212-L214) and [here](https://github.com/hcheng826/fhenix-dark-forest/blob/e10065f72351c8d1c65881395ed42046abfabf0f/test/DarkForestFHE.t.sol#L144-L146)
  
3. `Console.sol` doesn't compile for Foundry. Not sure if it is expected behavior. Understand that it is meant to be used with Fhenix's Localfhenix Environment, not sure if any special comfiguration about compiler is needed to make it compatible.


# Foundry Template [![Open in Gitpod][gitpod-badge]][gitpod] [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

[gitpod]: https://gitpod.io/#https://github.com/fhenixprotocol/fhenix-foundry-template
[gitpod-badge]: https://img.shields.io/badge/Gitpod-Open%20in%20Gitpod-FFB45B?logo=gitpod
[gha]: https://github.com/fhenixprotocol/fhenix-foundry-template/actions
[gha-badge]: https://github.com/fhenixprotocol/fhenix-foundry-template/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

Fhenix provides a Foundry-based template for developing Solidity smart contracts and includes sensible defaults. Links
are provided to specific topics for further exploration.

## What's Inside

- [Forge](https://github.com/foundry-rs/foundry/blob/master/forge): Tools to compile, test, fuzz, format, and deploy
  smart contracts.
- [Forge Std](https://github.com/foundry-rs/forge-std): A collection of helpful contracts and utilities for testing.
- [Prettier](https://github.com/prettier/prettier): A code formatter for non-Solidity files.
- [Solhint](https://github.com/protofire/solhint): A linter for Solidity code.
- [PermissionHelper.sol](./util/PermissionHelper.sol): Utilities for managing permissions related to FHE operations.
- [FheHelper.sol](./util/FheHelper.sol): Utilities for simulating FHE operations.

## Getting Started

To create a new repository using this template, click the
[`Use this template`](https://github.com/fhenixprotocol/fhenix-foundry-template/generate) button at the top of the page.
Alternatively, install the template manually as follows:

```sh
$ mkdir my-project
$ cd my-project
$ forge init --template fhenixprotocol/fhenix-foundry-template
$ bun install # install Solhint, Prettier, and other Node.js deps
```

If this is your first time using Foundry, refer to the
[installation](https://github.com/foundry-rs/foundry#installation) instructions for guidance.

## Features

- Simulated FHE Operations: All FHE operations, including encryption, decryption, and encrypted data handling, are
  simulated to replicate their behavior in a network environment. This approach facilitates seamless development and
  testing without requiring a fully operational FHE network.
- Permissions: The template includes utilities (PermissionHelper.sol) for creating permissions related to FHE
  operations. These utilities enable users to test and verify that contracts correctly implement access-controlled
  actions, such as viewing balances of encrypted tokens. For more about permissions, see the [Fhenix Documentation] https://docs.fhenix.zone/docs/devdocs/Writing%20Smart%20Contracts/Permissions)
  section.

## Installing Dependencies

Follow these steps to install dependencies:

1. Install the dependency using your preferred package manager, for example: `bun install dependency-name`
   - If installing from Github, use: `bun install github:username/repo-name`
2. Add a remapping for the dependency in [remappings.txt](./remappings.txt), for example:
   `dependency-name=node_modules/dependency-name`

Note that OpenZeppelin Contracts is pre-installed as an example.

## Writing Tests

To write a new test contract:

1. Start by importing `Test` from `forge-std`.
2. Inherit the test contract.

Note that: Forge Std comes with a pre-instantiated [cheatcodes](https://book.getfoundry.sh/cheatcodes/) environment,
which is accessible via the vm property. To view the logs in the terminal output, add the -vvv flag and use
[console.log](https://book.getfoundry.sh/faq?highlight=console.log#how-do-i-use-consolelog).

This template includes an example test contract [FHERC20.t.sol](./test/FHERC20.t.sol).

For contracts utilizing FHE operations, insert FHE mock operations using the `FheEnabled` contract. By inheriting the
`FheEnabled` contract in the test contract, you gain access to FHE operations. The following code demonstrates this.

```solidity
import { FheEnabled } from "./util/FheHelper.sol";

contract MyTestContract is Test, FheEnabled {
    // Your test contract code here
}
```

During test setup, `initializeFhe` the FHE environment using the initializeFhe function:

```solidity
function setUp() public {
    initializeFhe();
}
```

For a complete example, including mocked encryption, decryption, sealing and permission usage, refer to the example
**tests** provided in the tests directory.

## Permissions

The **PermissionHelper** contract provides utilities for managing permissions related to FHE operations. These utilities
enable users to test and verify that contracts correctly implement access-controlled actions, such as viewing balances
of encrypted tokens.

Consider using the following code as an example for a **PermissionHelper** contract in a test contract:

```solidity
import { Test } from "forge-std/src/Test.sol";

import { ContractWeAreTesting } from "./src/ContractWeAreTesting.sol";
import { PermissionHelper } from "./util/PermissionHelper.sol";

contract MyContract is Test {
    ContractWeAreTesting private contractToTest;
    PermissionHelper private permitHelper;

    function setUp() public {
        // The contract we are testing must be deployed first
        contractToTest = new ContractWeAreTesting();

        // The PermissionHelper contract must be deployed with the address of the contract we are testing
        // otherwise the permission generated will not match the address of the contract being tested
        permitHelper = new PermissionHelper(address(contractToTest));
    }

    function testOnlyOwnerCanViewBalance() public {
        // Owner key and address
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);

        // Generate a permission for the owner using the permitHelper and the private key
        Permission memory permission = permitHelper.generatePermission(ownerPrivateKey);

        // Call function with permission
        uint256 result = permissions.someFunctionWithOnlyPermitted(owner, permission);
    }
}
```

Note that the `PermissionHelper` contract is initialized only after we know the address of the contract being tested.
The reason is that the permission generated by the `PermissionHelper` contract is tied to the address of the contract
that is being tested.

## Differences from Real FHE Operations

FHE operations in this template simulate the behavior of a real FHE network. Instead of processing encrypted data,
operations are performed on plaintext data, which enables seamless development and testing without the need for a fully
operational FHE network. However, there are important differences between these mocked FHE operations and actual FHE
operations:

- Gas Costs – Gas costs associated with the mocked FHE operations do not accurately reflect those of real FHE
  operations. Instead, they are based on gas costs of equivalent non-FHE operations.
- Security Zones – In this mocked environment, security zones are not enforced. Thus, any user can perform operations
  between ciphertexts, which would otherwise fail in a real FHE setting.
- Ciphertext Access – The mocked FHE operations do not enforce access control restrictions on ciphertexts, which allows
  any user to access any mocked "ciphertext." On a real network, such operations could fail.
- Decrypts during Gas Estimations: When performing a decrypt (or other data revealing operations) during gas estimation
  on the Helium testnet or Localfhenix, the operation returns a default value, as the gas estimation process does not
  have access to the precise decrypted data. This can cause the transaction to fail at this stage, if the decrypted data
  is used in a way that would trigger a transaction revert (e.g., when a require statement depends on it).
- Security – The security provided by the mocked FHE operations does not represent the high level of security offered by
  real FHE operations. The mocked operations do not involve actual encryption or decryption.
- Performance – The performance of mocked FHE operations is not indicative of the real FHE operation speed. Mocked
  operations will be significantly faster due to their simplified nature.

## Usage

The following list contains the most frequently used commands.

### Build

Compile and build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Deploy

**Note:** Anvil does not currently support FHE operations. Stay tuned for future updates on Anvil support.

Deploy to Anvil:

```sh
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For this script to work, it is necessary to have a MNEMONIC environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/).

For instructions on how to deploy to a testnet or mainnet, refer to the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

**Note:** Gas usage for FHE operations will be inaccurate due to the mocked nature of these operations. To see the
gas-per-operation for FHE operations, refer to the
[Gas Costs](https://docs.fhenix.zone/docs/devdocs/Writing%20Smart%20Contracts/Gas-and-Benchmarks) section in our
documentation.

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ bun run lint
```

### Test

Run the tests:

```sh
$ forge test
```

Generate test coverage and output result to the terminal:

```sh
$ bun run test:coverage
```

Generate test coverage with lcov report (you have to open the `./coverage/index.html` file in your browser, to do so
simply copy paste the path):

```sh
$ bun run test:coverage:report
```

## License & Credits

- This project is licensed under MIT.
- This project is based on the [Foundry Template](https://github.com/PaulRBerg/foundry-template)

Copyright (c) 2024 Paul Razvan Berg License (MIT) https://github.com/PaulRBerg/foundry-template/blob/main/LICENSE.md
