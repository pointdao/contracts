This doc explains the mechanics of the protocol and token. 

For a more general intro to Point DAO, check out [pointdao.org](https://pointdao.org).

## Contracts

```
// ERC20 governance token
Point

// Main treasury and governance controller
PointTreasury

// Generic governance, controlled by PointTreasury
PointGovernor

// Vesting contract for treasury tokens
Vesting

// Party-buy galaxies
GalaxyParty

// Safely custody galaxies with minimum necessary functions exposed for governance
GalaxyLocker

// Deploy all contracts above atomically
Deployer
```

## GalaxyParty

There are two main ways that GalaxyParty enables Point DAO to acquire a galaxy:
 - A galaxy owner can call `initiateGalaxySwap` followed by `completeGalaxySwap` on separate blocks to transfer their galaxy to the DAO and receive 1000 POINT.
 - A galaxy owner can call `createAsk` to list their galaxy for sale to the DAO. The owner asks for a certain ETH:POINT rate as well as an optional amount of POINT. If it is approved by governance, then anybody can contribute to filling the ask, and ultimately the DAO acquires the galaxy and distributes a total of 1000 POINT to the owner and contributors. There can only be one active Ask at a time.
 
For example: Alice owns `~zod` and values it at 1000 ETH. She wants to sell it, but she also wants to retain some Urbit voting power. She can call `createAsk(0, 1*10**18, 100*10**18)` meaning she would like to sell `~zod` at 1 ETH per POINT, and she wants 100 POINT for herself. If governance approves this ask, then anybody can contribute some of the 900 remaining unallocated ETH. When 900 ETH is hit, Alice receives 900 ETH and 100 POINT, the DAO receives the galaxy, and the contributors can claim their share of the remaining 900 POINT.

Note that a galaxy owner that transfers their galaxy to Point DAO via GalaxyParty *can not* automatically get it back. Once it's in the GalaxyLocker, it's up to the DAO what they do with the galaxy. The motivation for the project was for the DAO to vote on Urbit proposals with their galaxies in perpetuity, meaning it would stay in GalaxyLocker forever, but this is not enforced.

See the GalaxyParty [integration test](https://github.com/jgeary/point-dao-contracts/blob/master/contracts/test/GalaxyParty.integration.t.sol) to see a thorough example of how it works in code.

## Galaxy Locker

Rather than giving galaxies direcly to the token governed treasury, galaxies are transferred to the GalaxyLocker. GalaxyLocker exposes just enough functions for governance to set management, voting and spawn proxies. If governance wants to recover a galaxy from the locker, they must burn 1000 POINT. (More on token mechanics below).

## Governance and Urbit Proposals
The governance system uses standard general-purpose openzeppelin governance contracts, so it is battle-tested and compatible with tools like [Tally](https://www.withtally.com/). In the interest of minimizing transaction fees, the DAO should do snapshot votes for each Urbit proposal to get a yes/no answer, and then a proposer can propose an onchain transaction which would submit that winning answer to Urbit's Polls contract on behalf of each galaxy owned by the treasury.

## Token
POINT is an ERC20 token with a max supply of 266,664. This comes from:

- If GalaxyParty processed all 256 Urbit galaxies it would distribute 256,000 POINT tokens. Note that GalaxyLocker burns 1000 POINT if a galaxy leaves the locker, so the net supply does not increase when one galaxy is processed through GalaxyParty multiple times.
- The remaining 10,664 POINT makes up ~4% of the maximum supply and is intended for team, airdrops, grants and other incentives. It vests to the treasury over 8 years.

POINT is mintable and burnable. GalaxyParty is the only authorized minter and GalaxyLocker is the only authorized burner, forever. It is also pausable. Token transfers are paused at first, but governance can vote to unpause transfers. When transfers are paused, GalaxyParty can still mint, GalaxyLocker can still burn and the DAO can still vote. 

## To Do
- [x] Long term vesting contract for treasury POINT tokens
- [x] Audit and reconsider the relationship between the protocol/governance and the multisig - what authority does the multisig have, if any? 
- [ ] Figure out initial token distribution for future ~wen sale from multisig (i.e. how to fairly approve it)
- [ ] Research and implement option in Ask struct for galaxy owner to become the management proxy once governance acquires their galaxy, ideally without breaking continuity
- [x] GalaxyLocker contract with minimum necessary functions (for governance only) to store galaxies and require burning 1000 POINT to transfer galaxy elsewhere
- [ ] Thoroughly test the governance module voting on Urbit proposals
- [ ] Research ideal governance parameters (timelock, voting period, quorum, proposers and executors, etc) to maximize fairness and compatibility with Urbit governance and minimize attack surface area.
- [ ] Write script that can run Deployer contract and verify all contracts on etherscan
- [ ] Deploy on testnet, manually test
