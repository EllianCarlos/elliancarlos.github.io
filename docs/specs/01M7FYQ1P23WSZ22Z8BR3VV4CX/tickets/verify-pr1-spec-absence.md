---
id: verify-pr1-spec-absence
blocked_by: []
---

Verify that PR #1 (`8ea98e1`) merge diff (`8ea98e1^1..8ea98e1`) and the current tree on `main` contain no spec or ticket files from the PR #1 pipeline run.

Check that `git ls-files | grep -iE 'docs/specs/01M78Z5AP6P14VQW4MKHJ6SXYV'` returns empty, and `git diff --stat 8ea98e1^1 8ea98e1` lists only the 4 expected production files:
- `.github/workflows/ci.yml`
- `preprints/Token_on_Me_A_Token_Level_Dataset_of_Company_Authorship_in_FLOSS_Codebases.pdf`
- `scripts/check-build.sh`
- `src/_data/preprints.js`

Done when the absence of spec/ticket files from PR #1 is verified.
