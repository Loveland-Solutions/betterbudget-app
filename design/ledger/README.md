# Ledger design mockups

The static mockups from which the ledger look was chosen. **The app in `app/` is now the
source of truth.** Several rules were settled only after these were made (no month
subheadings, the symbol key, any-order entry), so don't build from these pictures. See
[ADR 0004](../../docs/decisions/0004-ledger-ui.md).

- Published canvas (private to the owner): https://claude.ai/artifact/PVysW4N9RyarWTr4zZMgV5
  - Page *Ledger · Midnight*: the chosen direction, with the forecast in its normal and
    short-before-payday states.
  - Page *Earlier directions*: Private Banking, the first Midnight draft, and Precision.
- `build.mjs` generates every `.dc.html` artboard from one synthetic data set:
  `node design/ledger/build.mjs`.
- `canvas.json` lays the artboards out on the canvas.
- `betterbudget-ledger.html` (gitignored) is the assembled canvas. It's rebuilt with the
  Claude Code `/design` skill, not by hand.
- The round-2 note on the canvas still mentions suggesting Khan Savings as cover. That
  was dropped: the app makes no savings suggestions.
