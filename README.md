# Rust bootstrap plan — audited revision 2

Research date: **October 30, 2026**. This bundle supersedes the first roadmap and prompt. It contains plans and research, not a compiler build, tested deployment, or ready-resolved source lockfile.

## Read order

1. **`AUDIT_AND_PRIOR_ART.md`** — findings, corrections, reuse decisions, new experiments, and unanswered build questions.
2. **`CODING_AGENT_PROMPT.md`** — implementation handoff with mandatory sequencing and practical acceptance gates.
3. **`RUST_BOOTSTRAP_ROADMAP.md`** — revised detailed work packages, resource/caching guidance, tests, and later ancestry work.
4. **`RESEARCH_INDEX.md`** — 31 additional source groups, observed revisions/status, and scope limitations. The roadmap retains its original 24 source groups.

## Principal changes

The plan now requires reference reproduction before inventing adapters. It adds concrete Gentoo/Guix normalization prior art; current Alpine/Chimera musl packaging; a separately scoped Rustic generated-C experiment; established GCC-backend self-bootstrap work; and reusable compiler tests, metrics, ABI/differential tools, and artifact comparison tools.

It explicitly separates required bootstrap fixes from distribution policy, host compiler linkage from produced-program linkage, and inspected recipes from executed builds. The canonical path remains native Linux x86-64/musl, independent mrustc seed, a pinned StageX reference endpoint, then extension to the frozen Rust 1.99.1 destination.

## Use

Give the complete bundle to the coding agent, starting with `CODING_AGENT_PROMPT.md`. Keep the source index available for specific failure investigation rather than making every listed project a runtime dependency. The proposed larger controller/CLI is an optional later shape, not the first task.

Source URLs and commit observations are provided for inspection. The implementer must resolve and verify the exact compatible bundle and archive hashes on the actual builder. No upstream source archive, generated compiler source archive, compiler binary, or font is included.
