---
id: verify-build-and-tree-integrity
blocked_by: [verify-pr1-spec-absence]
---

Verify repository integrity and test harness:
1. Confirm pre-existing docs (`.docs/hn-submission.md`, `.docs/mcp-tools-research.md`, `docs/superpowers/plans/2026-09-21-tty-design-system-migration.md`) are unchanged.
2. Run `bun run build && ./scripts/check-build.sh` and ensure all 341 assertions pass without error.

Done when the test suite passes completely and non-pipeline documentation integrity is confirmed.
