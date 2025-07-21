# sovBit DAO Smart Contract

A decentralized autonomous organization (DAO) platform built with Clarity for Stacks blockchain. This contract enables the creation and management of DAOs, membership, proposals, voting, and treasury operations.

---

## Features

- **DAO Creation:** Anyone can create a DAO with a name and initial token supply.
- **Membership & Tokens:** DAO tokens represent membership and voting power. Members can transfer tokens to others.
- **Proposals:** Members can submit proposals, vote (weighted by token balance), and execute proposals if passed.
- **Treasury:** DAOs have a treasury for STX deposits and withdrawals (admin only).
- **Read-Only Queries:** Fetch DAO, proposal, treasury, and voting data.

---

## Contract Overview

### Constants

Error codes for common failure scenarios (e.g., not a member, insufficient balance, already voted).

### Data Maps

- `daos`: DAO metadata (name, admin, member count, token supply)
- `dao-members`: Member token balances per DAO
- `proposals`: DAO proposals (title, description, creator, votes, executed status)
- `proposal-votes`: Tracks member votes on proposals
- `dao-treasury`: DAO treasury balances

### Public Functions

- `create-dao(name, initial-token-supply)`: Create a new DAO
- `transfer-token(dao-id, to, amount)`: Transfer DAO tokens to another member
- `submit-proposal(dao-id, title, description)`: Submit a proposal to a DAO
- `vote-proposal(dao-id, proposal-id, support)`: Vote on a proposal
- `execute-proposal(dao-id, proposal-id)`: Execute a proposal if passed
- `deposit-treasury(dao-id, amount)`: Deposit STX into DAO treasury
- `withdraw-treasury(dao-id, amount, to)`: Withdraw STX from DAO treasury (admin only)

### Read-Only Functions

- `get-dao(dao-id)`: Get DAO metadata
- `get-balance(dao-id, user)`: Get member's token balance
- `get-proposal(dao-id, proposal-id)`: Get proposal details
- `get-treasury(dao-id)`: Get DAO treasury balance
- `get-vote(dao-id, proposal-id, voter)`: Get a member's vote on a proposal
- `has-voted(dao-id, proposal-id, voter)`: Check if a member has voted
- `get-next-dao-id()`: Get next DAO ID
- `get-next-proposal-id()`: Get next proposal ID

---

## Usage

1. **Deploy the contract** to the Stacks blockchain.
2. **Create a DAO** using `create-dao`.
3. **Transfer tokens** to onboard new members.
4. **Submit proposals** and **vote** on them.
5. **Execute proposals** if they pass.
6. **Manage treasury** with deposits and withdrawals.

---

## Development

- **Language:** Clarity
- **Platform:** Stacks Blockchain
- **File:** sovBit.clar

---

## License

MIT License

---

## Author

musa juan

---

## Disclaimer

This contract is provided as-is. Use at your own risk. Review and audit before deploying to mainnet.
