# sovBit DAO Smart Contract

A decentralized autonomous organization (DAO) platform built with Clarity for Stacks blockchain, featuring enhanced governance and multi-signature treasury management.

---

## Features

- **Enhanced DAO Creation:** Create DAOs with configurable governance parameters
- **Role-Based Access Control:** Admin, Treasurer, and Member roles
- **Advanced Proposals:** Time-based voting periods with quorum requirements
- **Multi-Signature Treasury:** Configurable withdrawal limits and signature requirements
- **Emergency Controls:** Special handling for large withdrawals
- **Enhanced Governance:** Proposal states tracking and automated execution
- **Backward Compatibility:** Maintains support for legacy proposal functions

---

## Contract Overview

### Enhanced Governance Constants

- `VOTING_PERIOD`: 24 hours (144 blocks)
- `EXECUTION_WINDOW`: 7 days (1008 blocks)
- `MIN_QUORUM_PERCENTAGE`: 20% minimum participation
- Role definitions: `ROLE_ADMIN`, `ROLE_TREASURER`, `ROLE_MEMBER`

### New Data Maps

- `enhanced-proposals`: Extended proposal data with timing and type information
- `treasury-config`: Multi-signature settings and withdrawal limits
- `member-roles`: Role assignments and tracking
- `pending-transactions`: Multi-signature transaction queue
- `transaction-signatures`: Signature tracking
- `daily-withdrawals`: Daily withdrawal limits tracking

### New Public Functions

- **Treasury Management**
  - `setup-treasury-config`: Configure treasury parameters
  - `assign-role`: Manage member roles
  - `request-withdrawal`: Initiate multi-sig withdrawal
  - `sign-transaction`: Approve pending transactions

- **Enhanced Governance**
  - `submit-enhanced-proposal`: Create proposals with types and targets
  - `vote-enhanced-proposal`: Time-aware voting with weight
  - `execute-enhanced-proposal`: Auto-execution with state checks
  - `get-proposal-state`: Track proposal lifecycle

### New Read-Only Functions

- `get-member-role`: Check member's role
- `get-daily-withdrawn`: Track daily withdrawals
- `get-pending-transaction`: View transaction details
- `has-signed-transaction`: Check signature status
- `get-enhanced-proposal`: View enhanced proposal details
- `get-treasury-config`: View treasury settings

---

## Usage

1. **Deploy and Configure**
   - Deploy contract
   - Setup treasury configuration
   - Assign roles to members

2. **DAO Operations**
   - Create DAO with initial settings
   - Manage membership through token transfers
   - Submit and vote on proposals

3. **Treasury Management**
   - Configure withdrawal limits
   - Submit withdrawal requests
   - Collect required signatures
   - Monitor daily limits

4. **Governance**
   - Create typed proposals
   - Vote within time windows
   - Monitor quorum requirements
   - Execute passed proposals

---

## Development

- **Language:** Clarity
- **Platform:** Stacks Blockchain
- **File:** sovBit.clar

---

## Security Features

- Time-based voting periods
- Quorum requirements
- Multi-signature controls
- Daily withdrawal limits
- Emergency procedures for large transactions
- Role-based access control
- Input validation and safety checks

---

## License

MIT License

---

## Author

musa juan

---

## Disclaimer

This contract is provided as-is. Use at your own risk. Review and audit before deploying to mainnet.
