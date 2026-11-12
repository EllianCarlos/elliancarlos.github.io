---
id: build-verify-commit
blocked_by: [add-build-assertions]
---

Stop any dev server, run `bun run build && ./scripts/check-build.sh`, confirm
the new row renders first with the right metadata and no acceptance claim.
Commit on the branch with a conventional message and no Co-Authored-By trailer.
Do not push.

Done when the full check passes and the commit exists.
