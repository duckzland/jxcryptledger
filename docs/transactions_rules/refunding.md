# Transaction Refund Rules (`TransactionsRulesRefund`)

## Core Requirements

- `tid != '0'` — refund must reference a valid existing transaction ID.  
- Original transaction (`origTx`) must exist.  
- Transaction must be **active** before refunding.  

## Structural & Linkage Rules

- Transaction must be a **leaf** (cannot be root).  
- Root transactions that are closed cannot be refunded.  
- Leaf transactions must have valid parent and root linkage (`parentTx != null`, `rootTx != null`).  

## Balance & Parent Rules

- Transaction must have sufficient remaining balance for refund.  
- Parent transaction must exist and its `rrId` must match the leaf’s `srId`.  
- If parent linkage mismatches → throw `txRefundParentMismatch`.  

## Child Relationship Rules

- Transaction must not have any children.  
- If children exist → throw `txRefundHasChildren`.  

## Validation Checks

- **Active Check**  
  - If transaction is not active → throw `txRefundInactive`.  

- **Leaf Check**  
  - If transaction is not a leaf → throw `txRefundRootClosed`.  

- **Balance Check**  
  - If balance ≤ 0 → throw `txRefundInsufficientBalance`.  

- **Original Exists Check**  
  - If `origTx` is missing → throw `txRefundNotFound`.  

- **Valid Leaf Linkage Check**  
  - If leaf missing parent or root → throw `txRefundInvalidLinkage`.  

- **Children Check**  
  - If transaction has children → throw `txRefundHasChildren`.  

- **Parent Mismatch Check**  
  - If parent’s `rrId` does not equal transaction’s `srId` → throw `txRefundParentMismatch`.  

## Summary

A REFUND transaction must reference a valid original record, be active, exist as a leaf with correct parent/root linkage, have sufficient balance, and must not have children. Parent linkage must match expected source account. Refunds enforce strict invariants to prevent invalid reversals and ensure hierarchical consistency.
