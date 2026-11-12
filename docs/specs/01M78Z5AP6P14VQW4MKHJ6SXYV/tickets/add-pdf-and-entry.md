---
id: add-pdf-and-entry
blocked_by: []
---

Verify the source PDF has no draft markers (no `CHECK:` text; title and
authors match `main.tex`). Copy it to `preprints/Token_on_Me_A_Token_Level_Dataset_of_Company_Authorship_in_FLOSS_Codebases.pdf`
(match the existing underscore naming). Prepend the entry to
`src/_data/preprints.js` per the spec (venue "preprint", kind "data paper",
date 2026-11-10 with an explanatory comment, no host).

Done when `cmp` of source and copy passes and the entry has all required fields.
