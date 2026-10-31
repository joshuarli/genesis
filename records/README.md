# Records

These files preserve the campaign's observed results and the StageX reference
pin. They are historical evidence, not build inputs. Executable recipes and
input hashes live in `recipes/`, `patches/`, `support/`, and `sources.toml`.

- `handoffs/` — per-stage rustc/cargo/LLVM/native handoff records.
- `stagex/` — pinned StageX Containerfile, package recipe, and pin record.
- `reports/` — the partial S10 replay, the bounded lower-chain report, and the
  Rustic X0 gate.
