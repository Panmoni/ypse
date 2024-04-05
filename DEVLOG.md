# DEVLOG

npx create-eth@latest
https://docs.scaffoldeth.io/

## 2024-04-04T18:03:26.3NZ

    Start the local development node (initialize local chain)
    	yarn chain

    	In a new terminal window, deploy your contracts
    	yarn deploy

    	In a new terminal window, start the frontend
    	yarn start

- [ ] consider using https://www.dynamic.xyz/

launch the chain, play with the sample contract

Edit the app config in packages/nextjs/scaffold.config.ts

Hardhat => packages/hardhat/test to run test use yarn hardhat:test

## 2024-04-05T20:27:49.3NZ

1537 moved my yapbay contracts into here

Account.sol
Arbitration.sol
ContractRegistry.sol
Escrow.sol
Offer.sol
Rating.sol
Reputation.sol
Trade.sol

1610 Crazy amount of dependencies not meshing properly.

1623 Hmm I thought this would automatically make the interfaces

had to quit chain and create new one.
then deploy, then start

1646 got it working well it seems.

yarn chain
yarn deploy
yarn start

Generating typings for: 10 artifacts in dir: typechain-types for target: ethers-v6
Successfully generated 36 typings!
Compiled 10 Solidity files successfully (evm target: paris).
deploying "ContractRegistry" (tx: 0x592522cc22b66cc39b0f74a2638addda9b3a870d93d4995f4bf29a99ef6fa9ab)...: deployed at 0x5FbDB2315678afecb367f032d93F642f64180aa3 with 392177 gas
deploying "Account" (tx: 0x6591e567da1b35e9e05e76e65221e735eddb5443036bc874d4f3a00a9524d1ae)...: deployed at 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 with 1483658 gas
deploying "Escrow" (tx: 0x6641465fc95c7646faac84e1bbf84c199df89b37c1d2c93226d0f37159ea9e2c)...: deployed at 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 with 1370131 gas
deploying "Arbitration" (tx: 0x3c7e1aedfaa811b3d2f8a113337c37be3dcccbbe5d09d308aa742a68941a98ad)...: deployed at 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 with 2039022 gas
deploying "Trade" (tx: 0x79eac4bad3c6e87377f40d03c45f247f89896d76b0cd4c54a9304907c3c644df)...: deployed at 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 with 3624803 gas
deploying "Offer" (tx: 0x3ad8de32fdd846218a63ffb46c67387572a0c55ec99e09ab2648a2d39ff1647f)...: deployed at 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 with 2168050 gas
deploying "Rating" (tx: 0xc9eed29fb3c0bcc93f2763b3fd268633b2210665eed7225cd6ccfcdc126787b8)...: deployed at 0x0165878A594ca255338adfa4d48449f69242Eb8F with 994533 gas
deploying "Reputation" (tx: 0xfb193fb24d282d8faef268816205bd11eaa669af4fd0f060358eb55c3786feb6)...: deployed at 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853 with 385540 gas
ContractRegistry addresses updated
📝 Updated TypeScript contract definition file on ../nextjs/contracts/deployedContracts.ts
