---
id: add-build-assertions
blocked_by: [add-pdf-and-entry]
---

In the `preprints` section of `scripts/check-build.sh`, add assertions derived
from the build: each PDF href in `dist/preprints/index.html` (flatten newlines
with `tr '\n' ' '` first) resolves to a file in `dist/`, and the row count equals
the entry count read from `src/_data/preprints.js`. Name no title, venue or
total. Mutation-test: delete the new PDF and drop a row, confirm the suite
fails on those exact lines, restore.

Done when both assertions pass on the real build and fail under each mutation.
