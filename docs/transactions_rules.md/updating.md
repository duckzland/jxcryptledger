# Transaction Update Rules (`TransactionsRulesUpdate`)

## Core Requirements

- `tid != '0'` — updated transaction must reference a valid existing ID.
- Required fields > 0: `srId`, `rrId`, `srAmount`, `rrAmount`, `timestamp`.
- `srId != rrId` — source and result accounts must differ.
- Original transaction (`origTx`) must exist.

## Structural & Linkage Rules

- Root transactions cannot change `pid` or `rid`.
- Leaf transactions must have valid parent and root (`parentTx != null`, `rootTx != null`).

## SR/RR Modification Rules

- SR/RR fields (`srId`, `rrId`, `srAmount`, `rrAmount`) cannot change if the transaction has children.
- If increasing `srAmount`, parent must have sufficient remaining balance.

## Status Transition Rules

Status changes must follow strict invariants:

### To `inactive`

- Must have children.
- Original balance must be zero.

### To `active`

- If no children → `balance > 0`.
- If has children → all children must be closed.

### To `partial`

- Must have children.
- Terminal leaves must not all be closed.

### To `closed`

- Transaction must not be root.
- A valid `targetCloser` must exist.

## Closable Flag Rules

When `closable` changes:

### Setting `closable = true`

- If root → all children must be closed.
- If leaf → original must be active AND a valid `targetCloser` must exist.

### Setting `closable = false`

- Root cannot be not‑closable if all children are closed.
- Leaf cannot be not‑closable if active AND a `targetCloser` exists.

## Summary

An UPDATE transaction must reference a valid original record, maintain structural integrity, respect SR/RR constraints, follow strict status‑transition rules, and preserve closable semantics based on tree state and child relationships.
