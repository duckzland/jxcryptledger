# Transaction Deletion Rules (`TransactionsRulesDelete`)

## Core Requirements

- Transaction must be a **root** (`tx.isRoot == true`).
- Root ID rules apply: `pid == '0'` and `rid == '0'`.

## Terminal/Leaf State Requirements

Deletion is only allowed when the entire subtree is fully resolved.

### Terminal Leaves

- All terminal leaves must be **closed**.
- No active terminal children may exist.

### All Leaves

- All leaves must be either **closed** or **inactive**.
- No leaf may remain active.

## Summary

A DELETE operation is only valid for a root transaction whose entire subtree is fully resolved: all terminal leaves closed, all leaves inactive or closed, and no active descendants remaining.
