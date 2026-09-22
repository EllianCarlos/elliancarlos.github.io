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

Formatting: Prettier with `printWidth: 80` and `proseWrap: "always"` (see `.prettierrc`).

## Design system (TTY)

All styling comes from the TTY design system. Read `src/styles/tty.css` first — it is an
`@import` list and it names every part in load order.

- `src/styles/tty/tokens/` — **eight files copied byte-for-byte from the design system
  archive.** Do not edit them and do not run Prettier over them. To take a new version of
  the system, re-copy all eight.
- `src/styles/tty/webfonts.css` — **this site's own file, not a copied one.**
  `tokens/fonts.css` fetches Silkscreen from the jsdelivr `@latest` tag, which is mutable,
  so this file re-declares the two faces against `silkscreen@5.3.0`. It must stay imported
  after the tokens: two `@font-face` rules for the same family, weight and style resolve to
  the last one declared. Keep every `@import` line at the top of `tty.css`, above any rule —
  an `@import` after a style rule is ignored.
- `src/styles/tty/core.css` — Button, Tag, Badge, KeyHint, Divider, Panel, Tabs, Input,
  MenuList as `.tty-*` classes.
- `src/styles/tty/content.css` — the post row, terminal window, foldout, caret and prose
  wrapper.
- `src/styles/tty/layout.css` — the page shell, screen grids, and the per-screen blocks
  (post, hero, list, paper row, search overlay). It also declares this site's own two
  non-vendored tokens on `:root`: `--tty-nav-h` (the nav height, read at three sites here
  and one in `prose.css`) and `--tty-prose-size` (the reading size, read by `.tty-prose` in
  `content.css` and by the post column here — both must read it, or `68ch` resolves to a
  width the text is not actually set in), plus `--font-marker`, the fallback stack for the
  Unicode glyphs that the latin web-font subset does not carry.
- `src/styles/tty/prose.css` — the Markdown body treatment.
- `src/styles/tty/prism-tty.css` — Prism token colours and the code-block chrome. It owns
  the toolbar CSS that used to come from the CDN, because `.eleventy.js` injects its Prism
  block before `</body>` and a CDN stylesheet there wins every tie.

Macros mirror the CSS: `src/_includes/tty/core.njk` (`btn`, `tag`, `badge`, `keyhint`,
`divider`, `panel`) and `src/_includes/tty/content.njk` (`postrow`, `terminal`, `foldout`).
`panel`, `terminal` and `foldout` take their body through `caller()`, so call them with
`{% call %}`. A class that appears in a macro must exist in the matching CSS file.

The rules that matter when you write new markup: two fonts, one accent colour
(`--yellow`), square corners, 1px rules or `--shadow-hard` instead of soft shadows,
stepped easing, no emoji, no SVG icons — Unicode glyphs only. Two layouts, not five:
compact below 1280px and desktop at 1280px and up.

An icon is a Unicode character in `--font-marker`, on a fixed `1ch` cell, and
`aria-hidden`. Two live examples: the list markers in `prose.css` (`▪ ○ ●`) and the nav
search glyph in `layout.css` (`⌕`, U+2315). Never reach for an SVG or an emoji, and never
let a glyph carry meaning that no text also carries — the search button's name comes from
its `aria-label`.

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

- `public/` is copied verbatim to the site root. Underscore-prefixed files are ignored by
  default, so `public/_headers` (cache-control rules) has an **explicit** passthrough copy.
- Passthrough also covers `src/styles`, `src/scripts`, `src/**/*.png`, the resume PDF,
  `robots.txt`, and favicons.
- Build output goes to `dist/` (gitignored). Directory config in `.eleventy.js`:
  input `src`, includes `_includes`, data `_data`.
- `sitemap.njk` generates `/sitemap.xml`; a `prettyPrintSitemap` transform inserts
  newlines. Sitemap hostname is hardcoded to `https://www.elliancarlos.com.br`.

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
