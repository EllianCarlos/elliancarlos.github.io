# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal website/blog (elliancarlos.com.br) built with **Eleventy (11ty) 2.x**, Nunjucks
templates, and Markdown content. **Bun** is the package manager (not npm/pnpm). The dev
environment is provisioned via **Nix + devenv + direnv** — entering the directory
auto-loads the shell and installs Bun + dependencies. The visual layer is the **TTY
design system** — a TUI-flavoured system vendored into `src/styles/tty/`. Pico CSS was
removed in the design system migration.

## Commands

```bash
bun run start    # dev server with live reload (localhost:8080)
bun run build    # production build → dist/
bun run clean    # rm -rf dist
```

Inside the devenv shell, `build` and `clean` are also exposed as bare scripts, and
`processes.dev.exec` runs `bun run start`.

There is **no unit test suite, linter, or typecheck**. Verification is
`bun run build && ./scripts/check-build.sh` — an assertion harness over the built `dist/`
tree. It never builds, so it cannot fight `eleventy --serve`; stop the dev server before
you build. Inside the devenv shell, `check` does both steps. CI runs the same script.

**Add an assertion to `scripts/check-build.sh` for every change you make.** It is the only
regression net this repository has.

Two rules for writing one, both learned from assertions that looked fine and tested
nothing:

- **Assert the relationship, never the copy.** Derive both sides from the build — a count
  against a count, one element's text against another's. An assertion that names a post
  title, a tag, a venue or a total turns CI red on an ordinary authoring turn.
- **Flatten newlines before you count tags.** `grep` is line-based, so an opening tag
  written across two lines matches neither `<a href="…"[^>]*>` nor the stricter pattern
  beside it. It vanishes from *both* sides of a comparison, the totals still agree, and the
  assertion silently stops watching the one tag it was written for. Pipe through
  `tr '\n' ' '` first. This already happened once, to the footer's source link.

Mutation-test every assertion you add: break the thing it guards, confirm the suite fails
on that exact line, and restore. An assertion that never failed has not been tested.

Formatting: Prettier with `printWidth: 80` and `proseWrap: "always"` (see `.prettierrc`).

## Design system (TTY)

All styling comes from the TTY design system. Read `src/styles/tty.css` first — it is an
`@import` list and it names every part in load order.

**Pages link `/styles/tty.bundle.css`, never `/styles/tty.css`.** `scripts/bundle-css.mjs`
concatenates the imported files (13 of them today, 14 before the Silkscreen pin went away),
in the order that list gives, as the last step of
`bun run build`. The import list is still the source of truth for cascade order and is
still asserted on; it is just not what a browser fetches.

The reason is measured, not theoretical: `tty.css` is 1 KB, and a browser cannot see its
imports until it has fetched and parsed it — so the real stylesheet arrived on a **second
round trip, 80 KB across 15 render-blocking requests**. It is one request now. Keep
authoring in the split files; only delivery is joined. `check-build.sh` fails if any page
links the import list, if an `@import` survives into the bundle, or if the bundle is
missing any file the list names.

**Third-party stylesheets load only on the pages that need them.** KaTeX's CSS used to sit
in `layout.njk`'s `<head>` unconditionally — and exactly one page of 39 renders maths, so 38
blocked first paint on a request that styled nothing. The `injectKatexStyles` transform adds
it to pages containing KaTeX markup, the same way `injectPrismPlugins` handles Prism. It is
injected into `<head>`, not before `</body>`: a stylesheet at the end of the body applies
after the maths has already painted as raw TeX. `check-build.sh` compares the set of pages
carrying the markup against the set carrying the stylesheet, so both sides come from the
build and adding a post with maths needs no change.

- `src/styles/tty/tokens/` — **eight files copied byte-for-byte from the design system
  archive.** Do not edit them and do not run Prettier over them. To take a new version of
  the system, re-copy all eight.
  Keep every `@import` line at the top of `tty.css`, above any rule — an `@import` after a
  style rule is ignored.
- There used to be a `src/styles/tty/webfonts.css` here, pinning Silkscreen against
  `silkscreen@5.3.0` because `tokens/fonts.css` names the mutable `@latest` tag. **The site
  sets no text in Silkscreen any more** (see "One font" below), so that file had nothing
  left to pin and it is gone. A family no rule matches is never fetched, so the vendored
  `@font-face` rules cost nothing. JetBrains Mono needs no such override:
  `tokens/fonts.css` already names `jetbrains-mono:vf@5.3.0`.
- `src/styles/tty/core.css` — Button, Tag, Badge, KeyHint, Divider, Panel, Tabs, Input,
  MenuList as `.tty-*` classes. One rule draws every key cap: `.tty-keyhint kbd,
  .tty-kbd`. Use `.tty-kbd` for a key inside a sentence (the "press `/` anywhere" hint on
  `/posts/`) and the `keyhint` macro for a key group. Never add a second key style — a key
  must not render two ways on one site.
- `src/styles/tty/content.css` — the post row, terminal window, foldout, caret and prose
  wrapper.
- `src/styles/tty/layout.css` — the page shell, screen grids, and the per-screen blocks
  (post, hero, list, paper row, search overlay). It also declares this site's own
  non-vendored tokens on `:root`: `--tty-nav-h` (the nav height, read at three sites here
  and one in `prose.css`) and `--tty-prose-size` (the reading size, read by `.tty-prose` in
  `content.css` and by the post column here — both must read it, or `68ch` resolves to a
  width the text is not actually set in), plus `--font-marker`, the fallback stack for the
  Unicode glyphs that the latin web-font subset does not carry, and the two display-face
  tokens described under "One font" below. It is also where the two vendored-token
  overrides live: `--text-faint` and `--font-display`. `tokens/` is byte-for-byte copied
  and must not be edited, and `layout.css` is imported after it, so an override belongs
  here.
- `src/styles/tty/prose.css` — the Markdown body treatment.
- `src/styles/tty/prism-tty.css` — Prism token colours and the code-block chrome. It owns
  the toolbar CSS that used to come from the CDN, because `.eleventy.js` injects its Prism
  block before `</body>` and a CDN stylesheet there wins every tie.

Macros mirror the CSS: `src/_includes/tty/core.njk` (`btn`, `tag`, `badge`, `keyhint`,
`divider`, `panel`) and `src/_includes/tty/content.njk` (`postrow`, `terminal`, `foldout`).
`panel`, `terminal` and `foldout` take their body through `caller()`, so call them with
`{% call %}`. A class that appears in a macro must exist in the matching CSS file.

The rules that matter when you write new markup: one font, one accent colour
(`--yellow`), square corners, 1px rules or `--shadow-hard` instead of soft shadows,
stepped easing, no emoji, no SVG icons — Unicode glyphs only. Two layouts, not five:
compact below 1280px and desktop at 1280px and up.

**One font.** The design system ships two: Silkscreen for display and JetBrains Mono for
everything else. This site now sets both in **JetBrains Mono**, and the reason is
legibility, not taste. Silkscreen is a 1-bit pixel face, and every rule that used it also
set `-webkit-font-smoothing: none`, because a smoothed pixel font is mud. Together they
made the words a reader most needs hard to read: post titles, prose headings, the hero,
the wordmark and every chrome label. Those carry information, not decoration.

`layout.css` declares two tokens for it:

- `--font-display` — overrides the vendored `tokens/typography.css` value. JetBrains Mono
  is already loaded as the body and code face, as one variable file covering weights
  100-800, so the swap costs **no extra request**.
- `--weight-display` (`700`) — the display face needs a weight of its own. Silkscreen had
  one weight and drew every stem a full pixel wide, so it read as heavy at 400; an outline
  mono at 400 would sit at the same weight as the body copy under it and the hierarchy
  would flatten. **Every rule that sets `--font-display` must also set this**, and
  `check-build.sh` walks the four site stylesheets' declaration blocks to enforce it.

The uppercase and the tracked-out letter-spacing stay. What changed is the face, the
weight, and smoothing.

The `--display-*` size scale is deliberately **left alone**, and that is an arithmetic
result rather than a guess. Measured from the two font files — advance of `A`, and that
same glyph's real `yMax`, both at 1000 units per em:

| face | advance | cap height |
|---|---|---|
| Silkscreen | 0.750em | 0.625em |
| JetBrains Mono | 0.600em | 0.730em |

So at one `font-size` the new face is **20% narrower per character and 17% taller**.
Headings gain optical size, which is the point, and nothing can overflow, because every
one of them shrinks in width. A measure written in `ch` does move, though, because `ch`
*is* the advance: `.tty-h1--hero` went from `24ch` to `30ch` (24 × 0.750 ÷ 0.600) to hold
the same physical measure. That is the only `ch` measure on the display face — the `68ch`
prose measure reads the body face, which did not change.

Do not point a rule back at Silkscreen. If you ever do, restore the version pin first —
the vendored `@font-face` rules name the mutable `silkscreen@latest` tag, and the file
that pinned it is gone.

Five assertions hold all of this, and all five were mutation-tested. Two read the winning
`--font-display` out of the bundle and check its byte offset against the vendored
declaration; one compares display rules against display rules that also set the weight;
two hold the smoothing override. **They read a comment-stripped copy of the bundle**,
because the notes that explain the change quote the very declarations being searched for —
the first draft of one assertion went red on a comment rather than on CSS.

An icon is a Unicode character in `--font-marker`, on a fixed `1ch` cell, and
`aria-hidden`. Two live examples: the list markers in `prose.css` (`▪ ○ ●`) and the nav
search glyph in `layout.css` (`⌕`, U+2315). Never reach for an SVG or an emoji, and never
let a glyph carry meaning that no text also carries — the search button's name comes from
its `aria-label`.

**Contrast.** `layout.css` overrides `--text-faint` to `#7A7A71` (4.57:1 on
`--surface-root`). The vendored value is `--grey-600` `#5E5E58`, which is **3.04:1** — AA
for large text only, while all 28 of its uses are 12-15px metadata: dates, index numbers,
key caps, hint labels. Those are information, not decoration.

Measured ratios on `--surface-root`: `--text-primary` 16.11:1, `--text-secondary` 9.49:1,
`--text-muted` 5.85:1, `--text-faint` 4.57:1 after the override. `--grey-500` is 2.22:1 and
must never carry text.

**Never pair a text colour with `opacity` below 1.** Opacity composites toward the
background and undoes the colour: even `--text-muted` at `opacity: .8` is only 4.09:1.
`.tty-foot__row--quiet` did exactly that, and `check-build.sh` now sweeps the source for
it. Make text quieter with a colour, never with opacity.

Reading sizes: `--tty-prose-size` (18px to 20px) is the body size for every post and for
the biography. The vendored `--text-lg` tops out at 17px, which is a UI size — do not set
body copy in it. Code blocks, tables and post-row descriptions read `--text-md` (15px).
`--text-sm` and `--text-xs` are for metadata only: dates, index numbers, labels.

Three scripts, each loaded only by the page that needs it except the first:
`tty-search.js` (the `/` overlay, on every page), `tty-progress.js` (post pages),
`tty-typewriter.js` (`/posts/`). `check-build.sh` asserts the count, because each script
is browser code the suite cannot execute.

## Architecture

`.eleventy.js` is the heart of the project — nearly all custom behavior (collections,
filters, permalink logic, transforms) lives there rather than being spread across files.
Read it first before making changes.

### i18n (built for 4 languages, currently disabled)

The build machinery supports **4 languages: `en`, `pt`, `es`, `ja`**, but as of the
"Cleanup" commit the site builds **English-only**. Only `src/en/` exists on disk —
`src/pt/`, `src/es/`, and `src/ja/` were removed. Everything below describes how the
machinery behaves and how to bring a language back, not the site's current output.

- **The flag**: `.eleventy.js` sets `const I18N_ENABLED = false;` near the top of
  `module.exports`, with `ALL_LANGUAGES = ["en", "pt", "es", "ja"]` kept alongside it.
  While `I18N_ENABLED` is `false`, `languages = ["en"]` and `i18nEnabled` (exposed as a
  global) gates every i18n-aware template block — the language dropdown, `hreflang`
  tags, and the browser-language auto-redirect (`languageRedirect.njk`) all render
  nothing. To reactivate, flip the flag to `true` and recreate the `src/<lang>/`
  content directories (see below); the rest of the pipeline picks it up automatically.
- **Content layout** (when enabled): `src/<lang>/` holds each language's pages and
  `posts/`. English serves at root (`/`, `/posts/`); others are prefixed (`/pt/`,
  `/pt/posts/`, …).
- **Permalink computation**: a global `permalink` function in `.eleventy.js` strips the
  `/<lang>/` segment from the file path and re-adds the prefix for non-English locales.
  Locale comes from directory data files (`src/<lang>/<lang>.json` → `{ "locale": "..." }`).
- **Per-language collections** are generated in a loop over `languages`: `posts_<lang>`,
  `tags_<lang>`, `searchIndex_<lang>`. With the flag off this loop only ever runs for
  `en`. The plain `posts` collection is an English-only alias kept for backward
  compatibility.
- **Translations are linked by `translationKey`** in post frontmatter — the same key
  across `src/en/posts/x.md` and `src/pt/posts/x.md` marks them as the same post. Not
  meaningful today since no translated posts exist, but the field is harmless to set on
  new posts.
- **Untranslated fallback**: non-English post pages show `translationWarning.njk`
  (a banner) when viewing an English post under a translated path.
- **`switchLanguage` / `i18nUrl` filters** rewrite URLs between locales (used for the
  language dropdown and `hreflang` tags in `layout.njk`).
- **Auto-redirect** (`languageRedirect.njk`): on first visit, redirects to the browser
  language *only if a translated page actually exists* — it checks the `availableUrls`
  collection (a map of `lang → [urls]`). This guard exists to prevent the historical
  `/pt/pt/pt/...` redirect loop. It also bails out on 404 pages and respects the
  `preferredLanguage` localStorage key. Inert while `i18nEnabled` is false.

UI strings still live in `src/_data/i18n/<lang>.json` for all four languages (unused
files for `pt`/`es`/`ja` while the flag is off), exposed as the `i18n` global via
`src/_data/i18n.js` and referenced in templates as `i18n[locale].<path>`.

Note: `structuredData.njk` still hard-codes `"knowsLanguage": ["en", "pt", "es", "ja"]`
in the homepage Person schema — that's a stale claim while i18n is disabled and should
be revisited if this schema gets another pass.

### Templates & layouts

- `src/_includes/layouts/layout.njk` — base HTML (SEO meta, Open Graph, hreflang,
  the TTY stylesheet, GA). `post.njk` extends it for blog posts.
- Layout aliases: `layouts/post.njk` → `post`, `layouts/base.njk` → `base`.
- `src/_data/seo.js` — site-wide SEO/social constants (siteName, baseUrl, author).
- Styling: the **TTY design system** — see "Design system (TTY)" above.

### Blog features

- **Tags**: `src/tag/index.njk` paginates over the `tagPages` collection (all
  `{lang, tag}` pairs) to generate one page per tag per language. `tag.11tydata.js`
  computes each page's permalink and locale.
- **Search**: client-side via **FlexSearch**. `search-index.njk` emits one JSON file
  per language (`/search-index-<lang>.json`) from the `searchIndex_<lang>` collection;
  `tty-search.js` (the `/` overlay, see "Design system (TTY)" above) loads and queries
  it. The index's `contentExcerpt` is built by reading each post's raw file in
  `.eleventy.js` (truncated to 2500 chars).
- **Syntax highlighting**: server-side via `@11ty/eleventy-plugin-syntaxhighlight`, plus
  an `injectPrismPlugins` transform that appends Prism toolbar/copy-button scripts to any
  HTML page containing highlighted code.
- **Heading anchors**: `markdown-it-anchor` with a custom `slugifyHeading` (must match
  the TOC slug logic in `.eleventy.js`).

### One post listing

`/posts/` is the whole record. A post appears there the day it is written and never
leaves: there is one post collection (`posts_<lang>`), one listing, and no way to hide a
post from it. The page is the hero, then every post numbered and grouped by year, with a
tag rail that links to the existing `/posts/tag/<slug>/` pages — an `<aside>` at 1280px and
up, a `<details>` foldout below it, both from the same macro.

There used to be a second listing at `/posts/archive/`, reached by an `archived: true`
frontmatter flag that dropped a post from `/posts/`. Both are gone, along with
`postsActive_<lang>`, `tty-archive.js` and the sort toggle. Do not reintroduce a
per-post visibility flag without also deciding what the feed, the sitemap, `llms.txt` and
the search index do with it — the old flag touched none of them, which is why a reader
could find a post everywhere except the page that lists them.

The `.tty-list__*` blocks in `layout.css` are shared by `/posts/`, every tag page and
`/preprints/`. The name is `list`, not `archive`.

The hero above the list is an eyebrow plus a headline, and they must say different
things: `blog.eyebrow` carries the descriptive sentence, `blog.headline` names the page.
They once held the identical string, so the page printed one sentence twice.

When a UI string needs markup inside it — a key cap, a link, emphasis — keep **one** i18n
field and put a named slot in it, then `replace` the slot in the template. `blog.searchHint`
is the example: `"press {key} anywhere"` becomes `press <kbd class="tty-kbd">/</kbd>
anywhere`. A named slot is not the antipattern below: it survives any word order, so a
translation can move it. Splitting the sentence into `searchHintBefore` and
`searchHintAfter` is the antipattern, because it hard-codes English word order.

The typewriter line on `/posts/` holds the same string twice, in `data-text` and as the
element's own text — `tty-typewriter.js` types the attribute, and the text is what a reader
without JavaScript sees. They must stay identical; `check-build.sh` compares them.

**Never split a piece of prose across sibling data fields.** The headline used to be
`heroLine1`, `heroLine2` and `heroLine3`, joined in the template by hard `<br>` tags.
That forces the author to re-balance three strings after every edit, and the break points
cannot follow the viewport. One field is the rule; `.tty-h1--hero` caps its measure in
`ch` and sets `text-wrap: balance`, so the browser picks the breaks. `check-build.sh`
guards all of this: no `<br>` on the listing page, both declarations read out of the
`.tty-h1--hero` block, no `…Line<N>` key anywhere in `src/_data`, and the eyebrow's text
compared against the headline's. None of those assertions names the copy itself.

### Preprints

`/preprints/` lists papers from `src/_data/preprints.js`. Each row links straight to a PDF
in a new tab. The PDFs live in `preprints/` at the repository root and reach `dist/` through
a passthrough copy. Adding a paper is two steps: drop the PDF in `preprints/`, add an entry
to the data file.

Each entry needs `title`, `authors`, `venue`, `date` and `pdf`, and takes two optional
fields: `host`, the conference an accepted workshop paper runs inside (the row prints
`<venue> @ <host>`), and `kind`, a short category label — "short paper", "poster" — that
renders as a tag beside the date. Leave a key out to omit it. The data file documents all
seven fields; `check-build.sh` keys its assertions to the template's own class names and
separator, never to a venue or a kind, so renaming either never turns CI red.

`date` is the day the paper was **presented**, not the day the entry was written and not
the camera-ready date. A workshop usually runs on one day inside a longer `host`
conference, so take the day from the venue's own published programme and cite it in a
comment beside the value. Never carry a date over from a previous year's schedule. This
is an academic record: a wrong date is worse than a missing one.

### Post frontmatter

```yaml
---
title: "..."
date: 2025-07-13
layout: layouts/post.njk
language: en          # display label
locale: pt            # drives URL prefix & i18n (non-English posts); only matters if I18N_ENABLED
place: brazil
translationKey: my-post   # links translations across languages; inert while i18n is disabled
description: "..."    # used for SEO + search index
tags: [tools]
modified: 2025-08-01  # optional; shows "updated on"
---
```

### Assets & output

- `public/` is copied to **`dist/public/`**, not to the site root — the docs used to claim
  otherwise. Post bodies depend on that: they reference `/public/<image>.png`. Files that
  must be served from `/` need their **own explicit mapping** in `.eleventy.js`
  (`_headers`, the favicons, `og-image.png`). Adding a file to `public/` does not put it at
  the root, and a `<link>` pointing at one that is not mapped 404s — `check-build.sh` reads
  the icon hrefs back out of the built page to catch exactly that.
- `og/` at the repository root holds the generated social thumbnails, copied once to
  `dist/og/`. They are deliberately **not** under `public/`, which would ship all 1.2 MB of
  them twice. Same reasoning as `preprints/`: generated artefacts, not sources.
- Passthrough also covers `src/styles`, `src/scripts`, `src/**/*.png`, the resume PDF,
  `robots.txt`, and favicons.
- Build output goes to `dist/` (gitignored). Directory config in `.eleventy.js`:
  input `src`, includes `_includes`, data `_data`.
- `sitemap.njk` generates `/sitemap.xml`; a `prettyPrintSitemap` transform inserts
  newlines. Sitemap hostname is hardcoded to `https://elliancarlos.com.br`. The
  site canonicalises on the apex domain, with no `www`: `.eleventy.js`,
  `src/_data/seo.js` and `CNAME` must all agree on it.

### The contact address

`src/en/contact.njk` spells the separators out in words — `elliancarlos [at] gmail [dot]
com` — inside a `<span data-contact-email>`. There is **no address on the page in any
encoding, and no `mailto:` link**.

**Never put the address on that page in a reversible form.** That is the rule, and it rules
out every clever fix: HTML numeric or hex character references, a reversed string with
`unicode-bidi`, percent-escapes in a `mailto:`, a data URI, ROT13. Each is one transform
away from plain text, so each hands a scraper the address for the cost of a single line.
This page did use numeric character references for one commit; `html.unescape` undoes them,
which is why it changed.

The cost is real and deliberate: the address is not clickable, and a reader retypes it.
Restoring the click means assembling the address in the browser at click time, which needs
a fourth script — and `check-build.sh` asserts the script count, so that is an explicit
decision rather than a quiet one.

Do **not** add an `aria-label` carrying the plain address to make the row read better
aloud. That puts the address back in the markup. A screen reader reads the words as
written, which is verbose but unambiguous.

The page lists five channels: the address, git, work, academic cv, orcid. Every one that
leaves the site carries `target="_blank" rel="noreferrer noopener"`, and `check-build.sh`
counts both sides so a new row cannot skip it.

**Mastodon is retired.** The account is out of use, so the row, the footer link, the
`seo.social.mastodon` key and the `sameAs` entry in `structuredData.njk` are all gone — and
with them the only `rel="me"` on the site. `check-build.sh` sweeps every built page for the
word, because a leftover inside a JSON-LD block is invisible to any row count. To retire
another profile, remove all four places; do not leave the `seo.social` key as an empty
string, which that object's note reserves for an account not yet created.

The research curriculum is called **"academic cv"** everywhere — never "lattes", never
"cv". The label is `i18n[locale].nav.academicCv` at all three sites that link it (footer,
homepage, contact page), and the URL is `seo.social.lattes` at all three, so neither the
name nor the address can drift. "Lattes" is the host, and appears only inside the URL text.
`check-build.sh` sweeps every built page for both retired labels.

Every `.tty-linklist` row on both pages reads **name → address**: the key column names the
channel, the link text is the URL (`git` → `github.com/elliancarlos`, `feed` → `feed.xml`).
Do not invert it. The academic-cv row used to, on the homepage, with an abbreviation in the
key and a name in the link.

`data-contact-email` is the assertion hook and carries no CSS. `check-build.sh` reads that
element's text and asserts it says something AND that what it says does not parse as an
address; it also asserts the page holds no `mailto:`, no `&#` character reference, and no
plain address anywhere. No assertion writes the address or the separators down, so both can
be rewritten freely.

### Links to the resume PDF

`/Ellian_Carlos_Resume.pdf` is a passthrough copy linked from three places: the header
nav, the footer, and the homepage link list. **Every link to it opens a new tab**, with
`target="_blank" rel="noreferrer noopener"`, because a PDF that replaces the page is a
dead end. It used to open a new tab from the header only.

A new-tab link must also say so to a screen reader. The accessible name is the visible
label followed by `i18n[locale].nav.opensPdfNewTab` — or `nav.opensNewTab` where the
visible text already ends in `.pdf`, so the word is not read twice. Keep the visible label
first in the accessible name, or WCAG 2.5.3 Label in Name breaks for voice control.

`check-build.sh` counts every link to the PDF and asserts that the same number carry both
attributes, so a fourth link cannot escape the rule.

Because the nav ships a new-tab link on every page, a whole-page grep for `target="_blank"`
now passes everywhere. Any assertion about a specific element's new-tab attributes must be
scoped to that element's own tag.

### Icons and social thumbnails

Generated by `scripts/make-images.mjs`, which runs **inside `bun run build`**. Nothing it
writes is committed — `og/` and the five generated PNGs in `public/` are gitignored, and
`check-build.sh` fails if any of them is ever added to the index.

```
"build": "eleventy && bun scripts/make-images.mjs && eleventy"
```

Eleventy runs **twice on purpose**. The first pass produces the pages the generator reads;
the second copies the new PNGs into `dist/` and lets `posts.11tydata.js` resolve each post's
own `ogImage`. A cold build — no font cache, no images, fresh clone — takes about 2.4s.

**Rendering uses `satori` + `@resvg/resvg-js`, never a system binary.** This is not a
preference, it is a hard requirement, and the reason is worth keeping:

- An earlier version shelled out to `magick`. That would have **failed on both hosts**.
  Netlify's build image and GitHub's ubuntu runner install Ubuntu's `imagemagick`, which is
  ImageMagick **6**, whose CLI is `convert`/`identify`. `magick` exists only in IM7. It
  worked on a dev machine with IM7 and nowhere else.
- Rewriting for IM6 was not viable either: IM6 is gone from nixpkgs, so its text-layout
  behaviour could not be verified anywhere before a production deploy.
- satori measures text from the font file rather than asking the system for a font, so
  output is byte-identical on every host. Verified: two independent checkouts with
  independent font downloads produced identical bytes for all eight sampled files.

**Do not add a system-binary dependency to the build.** If a new image operation is needed,
reach for a pinned npm package with prebuilt binaries.

`netlify.toml` pins the Netlify build command in the repository rather than the dashboard,
so the generation step cannot be lost to a UI setting nobody can review. Removing that file
hands control back to the dashboard; if its command is plain `eleventy`, the site deploys
with no favicon and no thumbnails. `check-build.sh` catches that state with nine failures.

Fonts are fetched to a gitignored `.fonts-cache/`, pinned to **commit shas, not branches** —
on `main` an upstream file move would break a deploy silently. CI caches the directory. Their
magic bytes are checked, because a truncated download or an HTML error page saved as `.ttf`
would render as blank glyphs rather than failing.

A new post has no thumbnail only if the generator is skipped; a normal build always makes
one. `src/en/posts/posts.11tydata.js` still falls back to `seo.defaultImage`, and
`check-build.sh` asserts every `og:image` resolves to a real file.

The icon is `> e` — an upright Bold `>` beside a Bold Italic `e`, the way Euler's number is
set. This used to carry a note on why the icon avoided Silkscreen: that face is caps-only,
so a lowercase `e` rendered as a capital E. Silkscreen is gone from the whole build now
(see "One font" above), so the generator loads one family and the social card's wordmark
reads the same face the pages do. Two glyphs is the ceiling for a 16px square; `>_e` and a
stacked `>_` over `e` were both tried and both collapse, and the script says so. Centring
comes from flex layout, never from a hand-tuned baseline offset — the first version used a
fixed nudge and sat visibly low.

The site default is **`/og/site.png`**, not `/og-image.png`. That old path served a
different image for years, so every platform that had scraped it kept showing the stale
picture after the bytes changed — LinkedIn and Facebook cache a card for days and only
re-fetch when told. **Changing an image's contents under a URL that has been shared does
not change what scrapers show.** Publish a new path instead. `/og-image.png` is still
generated, with the current bytes, so any cached card pointing there resolves rather than
404ing — a broken card is worse than a stale one.

A consequence for assertions: the default now also lives under `/og/`, so a check for
"`/og/` appears in a post's og:image" would pass on the fallback and test nothing. The
assertion compares each post's og:image **basename against its own directory name**
instead, accepting only `<slug>.png` or `site.png`.

Thumbnails are **1200×630**, asserted per file, with a 400 KB budget. The image this replaced
was 2848×1504 and **5.1 MB** — over the ceiling several scrapers enforce, so it may not have
rendered at all on some platforms. `og:image:width`/`height` are declared in `layout.njk`;
they are safe to hard-code only because the geometry assertion reads the real PNGs.

Title size is chosen by arithmetic, not a render-and-measure loop: JetBrains Mono is
monospace, so its advance is exactly 0.6em. The largest size whose wrapped line count fits
wins, so a short title is set large and a long one steps down.

## Deployment

Deployed via **Netlify** (status badge in README). `CNAME` → `elliancarlos.com.br`.
`public/_headers` sets cache-control (Netlify-style headers file).

## Conventions

- The site is English-only right now (see [i18n](#i18n-built-for-4-languages-currently-disabled)
  above) — there are no `src/es/`, `src/ja/`, or `src/pt/` homepages to keep in sync, so
  editing `src/en/index.njk` needs no mirroring today. The rule that used to require
  this lived in `.cursor/rules/translate-homepage.mdc`, deleted in the "Cleanup" commit;
  if `I18N_ENABLED` is flipped back on and the other language directories return,
  reinstate an equivalent rule (LATAM Spanish, e.g. "computadora" not "ordenador";
  Brazilian Portuguese, e.g. "você" not "tu"; identical HTML structure; localized
  internal links) before editing the homepage again.
- If i18n is ever re-enabled and posts get translated: copy the `src/en/posts/*.md`
  file into the target language directory, translate title/body/`description`, set
  `locale`, and keep the same `translationKey`.
