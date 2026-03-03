# Transaction Tree Example (Root → Leaves → Terminal States)

This is a simulated transaction tree showing multiple branches and mixed statuses (active, partial, inactive, closed). Useful for visualizing how rules apply across a full structure.

ROOT (tid=R1)
│
├── LEAF A (tid=A1) — active
│   ├── LEAF A1-1 (tid=A11) — partial
│   │   ├── TERMINAL (tid=A111) — active
│   │   └── TERMINAL (tid=A112) — closed
│   └── LEAF A1-2 (tid=A12) — inactive
│       └── TERMINAL (tid=A121) — closed
│
├── LEAF B (tid=B1) — partial
│   ├── TERMINAL (tid=B11) — closed
│   └── TERMINAL (tid=B12) — closed
│
└── LEAF C (tid=C1) — closed
    ├── TERMINAL (tid=C11) — closed
    └── TERMINAL (tid=C12) — closed

## Legend

- **ROOT** — pid=0, rid=0, closable=true, balance=rrAmount.
- **LEAF** — any non-root node with no children.
- **TERMINAL** — leaf with no further descendants.
- **active** — balance > 0, may have children.
- **partial** — has children, not all closed.
- **inactive** — no children, balance=0.
- **closed** — fully resolved, has valid targetCloser.

## Notes

- Branch A shows mixed states: active → partial → active/closed.
- Branch B shows a partial leaf whose terminal children are all closed.
- Branch C shows a fully closed branch.
- This structure is valid under your rule engine and demonstrates all major status transitions.
