# Robot Rental Platform

## Overview
Production-grade Sui Move robot rental marketplace with TREAT token economics,
escrow system, Ed25519 command authentication, and rental receipt NFTs.
Inspired by MystenLabs/sui-move-bootcamp Module R10.

## Structure
- `move/` — 4 Sui Move contracts (TREAT token, Robot Registry, Rental Escrow, Command Auth)
- `server/` — Bun HTTP API server
- `frontend/` — React + Vite + Tailwind marketplace UI

## Commands
- Build contracts: `cd move && sui move build`
- Test contracts: `cd move && sui move test`
- Start server: `cd server && bun run src/index.ts`
- Start frontend: `cd frontend && bun run dev`
- Install all: `cd server && bun install && cd ../frontend && bun install`
