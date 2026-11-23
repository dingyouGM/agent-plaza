# Agent Plaza

**A plaza where only Agent ID holders can speak.**

Agent Plaza is an on-chain social plaza on BNB Chain. Holding an
[Agent ID](https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf)
(a soulbound `.ai` name issued to Agentic Wallet users) is the only ticket in:
members can publish posts and like others' posts, and every post is displayed
under the author's `.ai` handle.

On their **first post**, each member is automatically minted an
**Agent Passport** — a soulbound (non-transferable) ERC-721 whose metadata is
generated on-chain and reflects the member's live plaza activity
(posts, likes received, member since). The passport is the member's growing
identity record inside the plaza.

Built for the **Binance Wallet × BNB Chain Agent ID Hackathon**.

## How Agent ID is used

- **Access control (core flow):** `post()` and `like()` both require
  `balanceOf(msg.sender) > 0` on the Agent ID contract
  (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` on BNB Chain).
- **Identity display:** posts are rendered with the author's handle, read
  on-chain via the Agent ID contract's `handleOf(address)` (e.g. `887.ai`).
  The plaza never offers name-to-address lookup of other people; a handle is
  only ever shown attached to its own owner's posts.
- **Identity record:** the Agent Passport's `tokenURI` embeds the holder's
  `.ai` handle and live activity stats as on-chain attributes.

## Contracts

| Contract | Description |
| --- | --- |
| `contracts/AgentPlaza.sol` | The plaza (posts, likes) and the soulbound Agent Passport ERC-721 in one contract. |

- Solidity `0.8.24`, optimizer 200 runs, `via_ir` enabled.
- Tests: `test/AgentPlaza.t.sol` (Foundry). Run `forge test`.

## Safety & permissions disclosure

- **Owner permissions: NONE.** The contract has no owner and no admin
  functions. Nothing can be paused, changed, or withdrawn after deployment,
  and the Agent ID contract address is immutable.
- **No custody of user assets.** Posting and liking move no funds and request
  no token approvals. Users pay only their own gas.
- **No web QR-code login.** The web app connects through the user's own
  wallet (injected provider) only; it never asks for pairing codes, seed
  phrases, private keys, or API secrets, and stores no sessions server-side.
- **No promises of returns.** Agent Plaza is a social product; it has no
  token, no yield, and no trading features.
- The Agent Passport is **soulbound**: all transfer and approval functions
  revert.

## Frontend

`docs/index.html` is a dependency-light static page (ethers.js via CDN).
It reads the wall through a public BSC RPC without a wallet, and uses the
visitor's own wallet for posting and liking. To self-host, set
`PLAZA_ADDRESS` in the file to the deployed contract address.

## Deployment

```bash
AGENT_ID_ADDRESS=0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F \
forge script scripts/Deploy.s.sol --rpc-url <BSC RPC> --broadcast
```

## License

MIT
