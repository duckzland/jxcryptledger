# Transaction Closing Rules (`TransactionsRulesClose`)

## Core Requirements

- **`srId != rrId`** — Cannot close a transaction that sends and receives the same asset/account.
- **Leaf only (`tx.isLeaf == true`)** — Root transactions (`pid == '0' && rid == '0'`) cannot be closed.
- **Active only (`tx.isActive == true`)** — Partial, closed, or finalized transactions cannot be closed directly.
- **Resolvable target (`targetCloser != null`)** — Closing is only allowed when climbing the ancestry resolves a valid parent or root node matching the closing leaf's output asset (`rrId`).

---

## Target Resolution (`getCloseTargetParent`)

When resolving `targetCloser` for a closing leaf `tx`, walk upward through its ancestors (`ctx` → `stx = txsMap[ctx.pid]`):

1. **Asset & Principal Gate:** An ancestor `stx` is a valid candidate when the child step entering it (`ctx`) matches the leaf's closing asset (`ctx.srId == tx.rrId`) and its input cost (`ctx.srAmount`) does not exceed `tx.balance`.
2. **Root Resolution:** If `stx.isRoot`, it is only valid if `stx.rrId == tx.rrId` (note: `isCapital` roots have `srId == rrId`, while trade roots use `rrId` as the tree's base asset).
3. **Highest Clean Target:** The traversal climbs as high as the chain allows—passing through intermediate 1:1 steps—and selects the highest matching ancestor (or `root` when the branch is eligible to return to root).

---

## Compounded Profit/Loss ("Toll-Booth" Split Ratio)

To prevent double-cutting principal across trees with partial trades or multiple sibling branches, cost basis is pro-rated along the single vertical path from `tx` to `targetCloser`:

1. **Cumulative Split Ratio (`shareRatio`):**
   - Start with `shareRatio = 1.0`.
   - At each intermediate step (`ctx` → parent `stx`), multiply by the fraction of `stx`'s output consumed by `ctx`:
     \[\text{shareRatio} \mathrel{*}= \frac{\text{ctx.srAmount}}{\text{stx.rrAmount}}\]
   - **Important:** Accumulate `stepRatio` *before* checking if `stx` is an intermediate `targetCloser`, and stop accumulating before dividing by `root.rrAmount`.
2. **Allocated Principal & Realized PnL:**
   - **Root target:** allocatedSeed = ctx.srAmount × shareRatio
   - **Intermediate leaf target (`ptx`):** usedParentAmount = ptx.rrAmount × shareRatio
   - **Net Profit/Loss:** tx.balance - allocatedPrincipal

---

## Worked Example (Partial Split Tree)

```text
[Root] 4,197 S -> 8,541 A   (unspent balance: 8,000 A)  <-- targetCloser
  └── 541 A -> 418 S        (split ratio: 541 / 8,541 = 6.334%)
        └── 418 S -> 774.48 A
              └── 774.48 A -> 577.346 S   (unspent balance: 159.35 S)
                    └── 417.996 S -> 593.7528 A   (split ratio: 417.996 / 577.346 = 72.400%)
                          └── ... (1:1 steps) ...
                                └── [Leaf] 472.5953 S -> 641.0698 A   (closing tx)
```

- **Target Resolution:** Climbing from `[Leaf]` (`rrId = A`) skips `577.346 S` (wrong asset) and lands on `[Root]` (`rrId = A`).
- **Cumulative Split Ratio:**
  $$\text{shareRatio} = \frac{541}{8541} \times \frac{417.996}{577.346} \approx 0.045859 \text{ (4.5859\%)}$$
- **Allocated Root Principal:** $8541\text{ A} \times 0.045859 = 391.6817\text{ A}$
- **Realized Profit:** $641.0698\text{ A} - 391.6817\text{ A} = +249.3881\text{ A}$
- **Balance Update:** `[Root].balance` becomes $8000 + 641.0698 = 8641.0698\text{ A}$; `[Leaf].balance` becomes $0$ (`closed`).

---

## State Mutation Invariants (No Double-Spend / Double-Cut)

When executing a close:

- **Zero out the leaf:** Set `tx.balance = 0` and transition `tx` to `closed` so it can never be closed or traded again.
- **Credit target `balance` only:** Add `tx.balance` to `targetCloser.balance`.
- **Never mutate `srAmount` or `rrAmount`:** Historical trade inputs/outputs (`srAmount`, `rrAmount`) are immutable anchors used to compute `shareRatio` for sibling branches. Mutating them corrupts cost-basis math for every remaining open leaf in the tree.

---

## Summary

A `CLOSE` operation is valid only for an active, non-root leaf (`srId != rrId`) with a resolvable `targetCloser`. Proceeds return to `targetCloser.balance`, while realized PnL is isolated to the closing branch using cumulative `srAmount / rrAmount` split ratios—keeping sibling branches completely independent.
