# Transaction Closing Rules (`TransactionsRulesClose`)

## Core Requirements

- `srId != rrId` — cannot close a transaction that sends and receives from the same account.
- Transaction must be a **leaf** (`tx.isLeaf == true`).
- Transaction must be **active** (`tx.isActive == true`).

## Closability Rules

- A valid `targetCloser` must exist.  
  Closing is only allowed when the tree structure determines a valid parent/root target for closure.

## Summary

A CLOSE operation is only valid for an active leaf transaction with distinct SR/RR accounts and a resolvable closure target. The transaction must not be a root and must be eligible for closure based on tree state.
