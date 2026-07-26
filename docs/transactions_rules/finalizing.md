# Transaction Finalization Rules (`TransactionsRulesFinalize`)

## Core Requirements

- `tid != '0'` — finalization must reference a valid existing transaction ID.  
- Original transaction (`origTx`) must exist.  
- Transaction must be either **active** or **partial** before finalization.  

## Structural & Linkage Rules

- Root transactions may be finalized only if all child leaves are inactive, closed, or already finalized.  
- Leaf transactions may be finalized only if their parent and root are valid and consistent.  

## Status & Hierarchy Rules

Finalization enforces strict invariants:

### Root Transaction

- Must be **active** or **partial**.  
- Cannot be finalized if any child transaction is still active.  
- All leaves must be either **inactive**, **closed**, or **finalized**.  

### Leaf Transaction

- May be finalized only if parent/root are valid.  
- Cannot be finalized if still active.  
- Must not break parent balance or linkage integrity.  

## Validation Checks

- **Active/Partial Check**  
  - If `origTx` is not active or partial → throw `txUpdateFinalizableRequiresActive`.  

- **Leaves Inactive Check**  
  - If any leaf is still active → throw `txUpdateFinalizableRequiresInactiveLeaves`.  

## Summary

A FINALIZE transaction must reference a valid original record, ensure the root is active or partial, guarantee all children are inactive/closed/finalized, and preserve hierarchical consistency. Finalization represents the terminal lock‑down of a transaction tree, preventing further updates once invariants are satisfied.
