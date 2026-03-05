# Transaction Trading Rules (`TransactionsRulesTrade`)

## Core Requirements

- `tid != '0'` — trade must reference a valid existing transaction.
- Required fields > 0: `srId`, `rrId`, `srAmount`, `rrAmount`, `timestamp`.
- `srId != rrId` — cannot trade between the same account.
- Original transaction (`origTx`) must exist.

## Structural Rules

- If original is a leaf → both `parentTx` and `rootTx` must exist.
- Original must be either **active** or **partial**.
- Original must have **positive balance**.

## Trade Validity Rules

- Trade cannot proceed if the original transaction is closed or inactive.
- Trade cannot proceed if the original transaction has invalid or missing linkage.
- Trade cannot proceed if the remaining balance is zero or negative.

## Summary

A TRADE operation is only valid when the original transaction exists, is active or partial, has valid parent/root linkage, has positive remaining balance, and contains valid SR/RR fields with distinct accounts.
