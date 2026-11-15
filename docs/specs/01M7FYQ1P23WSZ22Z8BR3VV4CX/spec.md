# Spec: Verify and Ensure Absence of Pipeline Spec Docs from PR #1

## Problem

The user requested updating PR #1 (https://github.com/EllianCarlos/elliancarlos.github.io/pull/1/changes) to remove the pipeline specs docs, as the project `elliancarlos.github.io` does not use the pipeline spec and tickets documentation pattern in its repository.

PR #1 (`pizza/01M78Z5AP6P14VQW4MKHJ6SXYV`) originally introduced `docs/specs/01M78Z5AP6P14VQW4MKHJ6SXYV/spec.md` and three ticket files in commit `271159b`. However, commit `27b7ac9` ("docs: remove pipeline spec docs from the PR") removed all four files, and commit `2b1b0c7` removed temporary agent files prior to merging. PR #1 was merged into `main` at commit `8ea98e1`.

Because PR #1 is merged, its changes on GitHub cannot be directly edited via a branch push, but verification is required to confirm that no spec or ticket files leaked into `main`, that only the intended 4 production files were merged, and that the website build and integrity tests remain 100% green.

## Solution

1. Verify git tree status on `main` and the diff of PR #1 merge commit (`8ea98e1^1..8ea98e1`) to confirm that zero pipeline spec or ticket documents exist in the merged diff or on `main`.
2. Ensure that existing non-pipeline markdown documentation (`.docs/hn-submission.md`, `.docs/mcp-tools-research.md`, and `docs/superpowers/plans/2026-09-21-tty-design-system-migration.md`), which pre-date PR #1, are preserved and not accidentally removed.
3. Validate that the Eleventy static site build and test suite (`bun run build && ./scripts/check-build.sh`) succeed with all 341 assertions passing.
4. If this job or future pipeline runs create temporary job spec files under `docs/specs/01M7FYQ1P23WSZ22Z8BR3VV4CX/`, ensure they are treated as pipeline artifacts not intended for final inclusion in the repository.

## Acceptance criteria

- `git diff --stat 8ea98e1^1 8ea98e1` confirms exactly 4 files were touched by PR #1: `.github/workflows/ci.yml`, `preprints/Token_on_Me_A_Token_Level_Dataset_of_Company_Authorship_in_FLOSS_Codebases.pdf`, `scripts/check-build.sh`, and `src/_data/preprints.js`.
- No files under `docs/specs/01M78Z5AP6P14VQW4MKHJ6SXYV/` or any other PR #1 spec/ticket files exist in the git index or on `main`.
- Pre-existing docs (`.docs/*`, `docs/superpowers/plans/*`) remain intact.
- `bun run build && ./scripts/check-build.sh` passes all 341 assertions.

## Seams

- Git tree seam: `git ls-files` and `git diff` verifying that PR #1 and `main` have no leftover pipeline spec files.
- Static site verification seam: `scripts/check-build.sh` executed against `dist/` following `bun run build`.
