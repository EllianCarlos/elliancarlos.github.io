# Spec: publish the MSR 2027 data paper on /preprints/

## Problem

The owner's MSR 2027 Data and Tool Showcase paper, "Token on Me: A Token-Level
Dataset of Company Authorship in FLOSS Codebases", exists only in the private
`ellians-masters` repository. The `/preprints/` page lists one paper. The new
one is missing, and so is any build check that stops a preprint row from
linking to a PDF that was never shipped.

## Solution

1. Copy `token-on-me-submission.pdf` from
   `~/Projects/ellians-masters/2026.2-estudos-pesquisa-sistemas/msr-2027-data-tool-paper/`
   into repo-root `preprints/` under a title-derived filename, following the
   existing underscore convention.
2. Prepend an entry to `src/_data/preprints.js`: title, authors (Ellian Carlos
   Costa, Arthur Pilone, David Tadokoro, Paulo Meirelles), `venue: "preprint"`,
   `kind: "data paper"`, no `host`, `date: 2026-11-10` with a comment saying it
   is the submission deadline (no presentation date exists), `pdf` pointing at
   the copied file.
3. Add relationship-based assertions to `scripts/check-build.sh`: every `pdf`
   path referenced by a built preprint row resolves to a file in `dist/`, and
   the number of rows equals the number of entries in `preprints.js`. Mutation
   test both.
4. Build and run the check with the dev server stopped. Commit on the branch
   with no Co-Authored-By trailer. No push.

## Acceptance criteria

- `preprints/` contains the new PDF, byte-identical to the source
  (`cmp` passes), and it appears in `dist/preprints/`.
- `/preprints/` renders the new row first, with the title, four authors in the
  order above, the venue text `preprint`, and a `data paper` tag.
- No row claims MSR 2027 acceptance anywhere in the page text.
- `bun run build && ./scripts/check-build.sh` passes.
- The new assertions fail when (a) the new PDF is deleted from `preprints/` and
  (b) a row is removed from the template or an entry added without a row, and
  pass again once restored.
- Existing assertions that name the first paper keep passing; none is edited to
  name the new paper's copy.
- The paper count text on the page stays grammatically correct (plural).
- The commit has no Co-Authored-By trailer.

## Seams

- `src/_data/preprints.js` to `src/en/preprints.njk` (rendered rows): entry
  count versus `class="tty-paper"` count in `dist/preprints/index.html`.
- Rendered link to the file in `dist/`: each row's PDF href resolves under
  `dist/` via the `preprints/` passthrough copy in `.eleventy.js`.
- `scripts/check-build.sh` as the only test harness, checked by mutation
  (delete the PDF, drop a row).
- Source PDF to repo copy: byte equality (`cmp`).
