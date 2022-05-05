This doc explains the mechanics of the protocol, token and DAO. 

For a more general intro to Point DAO, check out [pointdao.org](https://pointdao.org).

## Contracts and Architecture

The protocol is upgradeable following the EIP-2535 diamond pattern. This means that new functionality can be added without having to upgrade the entire protocol. There is shared state throughout the protocol, so new modules can access the same state that other modules can and modify it. These modules are called facets. The main Diamond contract keeps track of these facets and routes function calls to the correct facet. External accounts will only interact with Diamond.

Adding new facets will often require some initialization code that sets up new state variables or modifies existing state before the facets is 'cut'. Governance may also have one-off reasons to manipulate state even when they aren't cutting a new facet. This is all accomplished via migrations, which are the same thing as facets except that they can only be called once. This repository will keep track of all migrations even after they become irrelevant, and the protocol logs which ones have been run.

The governance contracts are completely separate from the protocol and are non-upgradeable.

```
// deploys entire protocol atomically
Deployer

// Upgradeability pattern designed by Nick Mudge
diamond
  │   // Protocol wrapper
  │   Diamond
  │
  └───facets
  │   │   // Misc admin functions
  │   │   AdminFacet
  │   │
  │   │   // Interact with Urbit contracts
  │   │   GalaxyHolderFacet
  │   │
  │   │   // Party-buy galaxies
  │   │   GalaxyPartyFacet
  │   │
  │   │   // ERC20 voting token
  │   │   PointTokenFacet
  │   │
  │   │   // Boilerplate (adapted from Aavegotchi, Nick Mudge)
  │   │   DiamondCutFacet
  │   │   DiamondLoupeFacet
  │   │   OwnableFacet
  │
  │   // tools shared by facets
  └───interfaces, libraries
  │
  │   // one-time state changes
  └───migrations

governance
  │   // Main treasury and timelocked governance controller
  │   PointTreasury
  │
  │   // Generic governance, controlled by PointTreasury
  │   PointGovernor
```

## GalaxyParty

GalaxyParty enables Point DAO to acquire a galaxy from a seller.

A galaxy owner can call `createAsk` to list their galaxy for sale to the DAO. The owner asks for some amount of ETH and some amount of POINT. If governance calls `approveAsk`, then anybody can `contribute` to filling the ETH portion of the ask. When the ETH amount is filled, and the DAO acquires the galaxy and distributes 1,000 POINT for every 1 ETH contributed as well as whatever POINT the seller asked for. There can only be one active Ask at a time.
 
For example: Alice owns `~zod` and values it at 1000 ETH. She wants liquidity, but she still wants to retain some Urbit voting power. She can call `createAsk(0, 900*10**18, 100_000*10**18)` meaning she would like to sell `~zod` for 900 ETH and 100,000 POINT. If governance calls `approveAsk`, then anybody can `contribute` some of the 900 remaining unallocated ETH. When 900 ETH is hit and `settleAsk` is called, Alice receives 900 ETH and 100,000 POINT, the DAO receives the galaxy, and the contributors can `claim` their POINT (the amount of ETH they contributed * 1,000).

The protocol takes a 3% fee on ETH raised and also mints an extra 3% of the total POINT minted for each settled ask, and sends both to the POINT-governed treasury.

The motivation for the project was for the DAO to vote on Urbit proposals with the protocol's galaxies in perpetuity, meaning galaxies stay in the protocol forever, but this is not enforced. There currently is no functionality for sending a galaxy out of the protocol, but the protocol is upgradeable by governance.

See the GalaxyParty [integration test](https://github.com/jgeary/point-dao-contracts/blob/master/src/test/GalaxyParty.integration.t.sol) to see a thorough example of how it works in code.

## Galaxy Holder

This part of the protocol interacts with Urbit's Ecliptic contract. It exposes just enough functions for governance to set management, voting and spawn proxies, and cast votes, but currently does not allow anyone to call `ecliptic.setTransferProxy` or `ecliptic.transferPoint`.

## Governance and Urbit Proposals
The governance system uses standard general-purpose openzeppelin governance contracts, so it is battle-tested and compatible with tools like [Tally](https://www.withtally.com/). Governance has added privileges throughout the contract, like upgrading the protocol and submitting Urbit Ecliptic votes.

## Token
POINT is an ERC20 token with extra voting functionality. The total supply should equal 1,000 x the total amount of ETH contributed towards acquiring galaxies, plus a small percentage of that which is owned by the governance-controlled treasury.

POINT is mintable and pausable. Token transfers are paused at first, but governance can vote to unpause transfers. GalaxyParty can still mint while transfers are paused. 

## To Do
- Get protocol audited
- Thoroughly test token holders' ability to vote on Urbit proposals via Point DAO governance
- Research ideal governance parameters (timelock, voting period, quorum, proposers and executors, etc) to maximize fairness and compatibility with Urbit governance and minimize attack surface area.
- Deploy scripts
- Deploy on testnet, manually test
