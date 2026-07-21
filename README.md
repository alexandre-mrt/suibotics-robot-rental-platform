# Robot Rental Platform

A robot-rental marketplace on [Sui](https://sui.io), built in Move. Robot owners
register hardware on-chain; renters pay with an in-app token to reserve a robot for
a bounded time window, and every command sent to a rented robot is authorized
on-chain via an Ed25519 challenge-response so only the current renter can drive it.

This is a solo learning/portfolio project. The contracts target Sui devnet/testnet
and are **not audited** — do not use them with real value.

## Architecture

Three components:

- `move/` — the on-chain logic (five Move modules).
- `server/` — a Bun HTTP API that builds unsigned Sui transactions for a client to sign.
- `frontend/` — a React + Vite + Tailwind marketplace UI with wallet integration (dApp Kit).

### Move modules (`move/sources/`)

| Module | Responsibility |
| --- | --- |
| `treat_token` | `TREAT`, a closed-loop payment token with a rate-limited faucet (5 claims / epoch, 100 TREAT per claim). |
| `robot_registry` | Registers robots as shared objects; owners hold a capability granting admin rights over their robot. |
| `rental_escrow` | Time-based billing. Escrows the renter's `TREAT`, tracks the active agreement, refunds overpayment, and mints a `RentalReceipt` NFT on settlement. Holds a `RentalCap` proving who the active renter is. |
| `command_auth` | Ed25519 challenge-response. Issues a per-renter challenge, verifies the signed response against the renter's key, and authorizes a command only for the holder of a valid `RentalCap`. |
| `reputation` | Post-rental ratings with basic dispute resolution; self-reviews are rejected. |

Access control is capability-based (`RobotOwnerCap`, `RentalCap`) rather than
address checks, following standard Sui object-ownership patterns.

### Server (`server/src/`)

A minimal Bun `fetch` server exposing:

- `GET /robots`, `GET /robots/:id` — list / fetch robots
- `POST /rentals`, `POST /rentals/:id/end` — start / end a rental
- `POST /commands/challenge`, `POST /commands/execute` — request and submit a signed command
- `GET /rentals/active`, `GET /receipts/:addr` — active rental and receipt history

Handlers build Programmable Transaction Blocks with the TypeScript SDK; signing
stays client-side.

## Getting started

Prerequisites: [Sui CLI](https://docs.sui.io/references/cli) and [Bun](https://bun.sh).

```bash
# Contracts
cd move && sui move build && sui move test

# API server
cd server && bun install && bun test && bun run src/index.ts

# Frontend
cd frontend && bun install && bun run dev
```

The Sui framework is pinned to `testnet-v1.72.1` in `move/Move.toml` so the test
suite reproduces against a known-good framework revision. If you upgrade the Sui
CLI, bump that `rev` to the matching release tag.

## Tests

| Suite | Command | Count | Status |
| --- | --- | --- | --- |
| Move contracts | `cd move && sui move test` | 39 | passing |
| API server | `cd server && bun test` | 10 | passing |

Counts measured on Sui CLI `1.72.1` / Bun `1.3.11`.

## Status & limitations

- Devnet/testnet only; unaudited.
- Move has no way to iterate a `Table` by value, so "does this address have an
  active rental?" is resolved off-chain via events/indexer rather than on-chain —
  the contracts key rentals by `rental_id`. Noted inline where it matters.
- The frontend is a functional demo, not production-hardened.
