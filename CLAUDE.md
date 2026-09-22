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
  (post, hero, archive, paper row, search overlay).
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

Four scripts, each loaded only by the page that needs it except the first:
`tty-search.js` (the `/` overlay, on every page), `tty-progress.js` (post pages),
`tty-typewriter.js` (`/posts/`), `tty-archive.js` (`/posts/archive/`).

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

### Archived posts

A post with `archived: true` in its frontmatter leaves the `/posts/` landing page and
nothing else. It keeps its URL, stays in `feed.xml`, `sitemap.xml`, `llms.txt` and the
search index, shows a banner on its own page, and appears on `/posts/archive/` with an
`ARCHIVED` badge. The `postsActive_<lang>` collection is the filtered one; `posts_<lang>`
is still everything.

`/posts/archive/` is the full record: every post, numbered, grouped by year, with a tag
rail that links to the existing `/posts/tag/<slug>/` pages and a sort toggle that is a CSS
flip rather than a re-sort.

### Preprints

`/preprints/` lists papers from `src/_data/preprints.js`. Each row links straight to a PDF
in a new tab. The PDFs live in `preprints/` at the repository root and reach `dist/` through
a passthrough copy. Adding a paper is two steps: drop the PDF in `preprints/`, add an entry
to the data file.

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
archived: true        # optional; drops the post from /posts/ only, see "Archived posts"
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
