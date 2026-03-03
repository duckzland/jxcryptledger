# Transaction Creation Rules (`TransactionsRulesCreate`)

## Core Requirements

- `tid != '0'` — no transaction may use `'0'` as its ID.
- Required fields must be > 0: `srId`, `rrId`, `srAmount`, `rrAmount`, `timestamp`.
- `srId != rrId` — source and result accounts must differ.
- `status == active` — all new transactions must start active.

## Root Rules (`tx.isRoot`)

- If `pid == '0'` → `rid == '0'` — root must use both pid/rid as `"0"`.
- If `rid == '0'` → `pid == '0"` — same rule in reverse.
- `balance == rrAmount` — root balance initializes to full result amount.
- `closable == true` — root must be closable at creation.

## Leaf Rules (`tx.isLeaf`)

- `rootTx != null` — referenced root must exist.
- `parentTx != null` — referenced parent must exist.
- `srId == parent.rrId` — leaf must consume from parent’s output account.
- `srAmount <= parent.balance` — leaf cannot overspend parent.
- Closable consistency:
  - If `closable == true` → `targetCloser != null`
  - If `closable == false` → `targetCloser == null`

## Summary

A CREATE transaction must be structurally valid, correctly linked, start active, follow account‑flow rules, respect parent balance, and satisfy root/leaf invariants.
