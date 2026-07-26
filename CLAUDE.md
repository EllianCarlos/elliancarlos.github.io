# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal website/blog (elliancarlos.com.br) built with **Eleventy (11ty) 2.x**, Nunjucks
templates, and Markdown content. **Bun** is the package manager (not npm/pnpm). The dev
environment is provisioned via **Nix + devenv + direnv** — entering the directory
auto-loads the shell and installs Bun + dependencies.

## Commands

```bash
bun run start    # dev server with live reload (localhost:8080)
bun run build    # production build → dist/
bun run clean    # rm -rf dist
```

Inside the devenv shell, `build` and `clean` are also exposed as bare scripts, and
`processes.dev.exec` runs `bun run start`. There is **no test suite, linter, or
typecheck** — verification means running `bun run build` and inspecting `dist/`.

Formatting: Prettier with `printWidth: 80` and `proseWrap: "always"` (see `.prettierrc`).

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
  across `src/en/posts/x.md` and `src/pt/posts/x.md` marks them as the same post. The
  `postInLanguage` filter checks whether a translation exists. Not meaningful today
  since no translated posts exist, but the field is harmless to set on new posts.
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
  Pico CSS, Prism theme, GA). `post.njk` extends it for blog posts.
- Layout aliases: `layouts/post.njk` → `post`, `layouts/base.njk` → `base`.
- `src/_data/seo.js` — site-wide SEO/social constants (siteName, baseUrl, author).
- Styling: **Pico CSS 2** (CDN) + `src/styles/style.css` and `blog.css`. Dark theme
  is forced via `data-theme="dark"` on `<html>`.

### Blog features

- **Tags**: `src/tag/index.njk` paginates over the `tagPages` collection (all
  `{lang, tag}` pairs) to generate one page per tag per language. `tag.11tydata.js`
  computes each page's permalink and locale.
- **Search**: client-side via **FlexSearch**. `search-index.njk` emits one JSON file
  per language (`/search-index-<lang>.json`) from the `searchIndex_<lang>` collection;
  `src/scripts/search.js` loads and queries it. The index's `contentExcerpt` is built by
  reading each post's raw file in `.eleventy.js` (truncated to 2500 chars).
- **Syntax highlighting**: server-side via `@11ty/eleventy-plugin-syntaxhighlight`, plus
  an `injectPrismPlugins` transform that appends Prism toolbar/copy-button scripts to any
  HTML page containing highlighted code.
- **Heading anchors**: `markdown-it-anchor` with a custom `slugifyHeading` (must match
  the TOC slug logic in `.eleventy.js`).

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
