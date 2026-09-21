# TTY Design System Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild every page of elliancarlos.com.br on the TTY design system, add a
`/preprints/` page, and add a `/posts/archive/` view that lists every post including
archived ones.

**Architecture:** The TTY design system ships React components with inline styles. This
site is Eleventy + Nunjucks with no client framework. We port the system, not the React:
the eight token CSS files are vendored verbatim into `src/styles/tty/tokens/`, and each
React component becomes a CSS class plus a Nunjucks macro. Pico CSS goes away
completely. Four small vanilla scripts cover the behaviour that needs JavaScript: the
`/` search overlay, the reading-progress readout, the hero typewriter, and the archive
sort toggle.

**Tech Stack:** Eleventy 2.x, Nunjucks, Markdown, Bun, FlexSearch 0.7.31, Prism (at build
time through `@11ty/eleventy-plugin-syntaxhighlight`), KaTeX, Nix + devenv.

**The output is a static tree.** `dist/` is HTML, CSS, JS, JSON and PDFs. Nothing in this
plan adds a form, an endpoint, a runtime dependency on a host, or a build step that runs
anywhere but a developer machine and CI. Search reads a JSON file the build generates. The
design system's newsletter block, the one component that would need a backend, is replaced
by a list of the site's own feeds — see Task 10.

## Global Constraints

Every task inherits these. They come from the design system `readme.md` and from the
answers the repository owner gave before this plan was written.

- **Two fonts only.** Silkscreen (display, chrome) and JetBrains Mono (everything you
  read). Both load from `cdn.jsdelivr.net` through `tokens/fonts.css`. No other webfont.
  Delete the Montserrat `@import`.
- **Silkscreen is never smoothed.** Every rule that sets `font-family: var(--font-display)`
  must also set `-webkit-font-smoothing: none;` and `font-smooth: never;`.
- **Silkscreen is never set below 15px** and never used for body copy or for a glyph.
- **One primary colour: `--yellow` (#FFD400).** It marks focus, selection, the active
  tab, the caret, links, and the wordmark. Nothing else.
- **The four ANSI accents are semantic only** (`--green` ok, `--cyan` info,
  `--magenta` special, `--red` error) plus syntax highlighting. Never decoration.
- **Square corners.** `border-radius: 0` everywhere. `--radius-pill` only for a status dot.
- **No soft shadows, no blur, no gradients, no background images.** Depth is a 1px rule
  or `--shadow-hard: 3px 3px 0 #000`.
- **Stepped motion.** Use the `steps()` easing tokens. `--ease-out` only for colour and
  border transitions. `prefers-reduced-motion` is already handled in `tokens/motion.css`.
- **Two layouts only.** Compact below 1280px, desktop at 1280px and up. Tablets get
  compact. Read the edge through `@media (max-width: 1279.98px)` and
  `@media (min-width: 1280px)`.
- **No emoji anywhere** — not in copy, not in UI, not in headings. Use the glyph
  vocabulary: `─ │ █ ▓ ▒ ░ ▸ ▾ ▪ ● ○ ◆ ⟳ ✕ ≡ › ↵ / ? $ → ·`.
- **No hand-drawn SVG icons. No icon font.** Glyphs only.
- **Voice: first person singular.** "I" is allowed, "we" is not. Flat and technical.
  Numbers and names instead of adjectives. No exclamation marks, no superlatives.
- **Casing:** `UPPERCASE` tracked for Silkscreen chrome (applied by CSS, never typed),
  `lowercase` for machine speech (commands, tags, file names, key hints), sentence case
  for prose. Never hand-type shouting copy.
- **Punctuation:** `·` separates facts on one line. `→` marks a result. `…` marks an
  in-progress state. `›` and `$` are prompts.
- **Reading measure is `--measure-prose` (68ch).** Page max is `--page-max` (1240px).
- **Never use a hard-coded colour, size, or duration** where a token exists.
- **Bun is the package manager.** Never run `npm` or `pnpm`.
- **No new browser-side dependency.** The migration adds no script the reader downloads
  beyond the four small files it writes itself, and FlexSearch, which the site already
  used. A build-time Markdown plugin is allowed on the same footing as the
  `markdown-it-anchor` and `@vscode/markdown-it-katex` the repository already has — but
  prefer a `markdown-it` renderer rule over a new package when both work.
- **The build output is static.** No form, no endpoint, no backend, no runtime host
  dependency. If a change needs a server to work, it is the wrong change.
- **Markdown is the authoring format.** A post is a `.md` file with frontmatter. No task
  in this plan asks the author to write HTML, a macro or a component to publish a post.
- **Every URL that exists today keeps working.** No redirects, no renames.
- **Verification is `bun run build` plus `./scripts/check-build.sh`.** There is no unit
  test suite. The built `dist/` tree is the proof.

## Decisions Already Taken

The repository owner answered these before the plan was written. Do not revisit them.

1. **Wordmark** is `elliancarlos` in Silkscreen, uppercase, `--yellow`, followed by a
   blinking block caret. Rendered `ELLIANCARLOS_`.
2. **Pico CSS 2 is removed completely.** No `--pico-*` variable survives.
3. **`/posts/` excludes archived posts.** A post is archived when its frontmatter sets
   `archived: true`.
4. **`/posts/archive/` is the full archive index** — every post, archived or not,
   as a numbered row, with a tag rail, a by-year rail, and a sort toggle. Archived rows
   carry an `ARCHIVED` badge.
5. **`/preprints/` is a single list page.** One row per paper: title, venue, date. The
   row links straight to the PDF and opens it in a new tab. No per-paper detail page, no
   generated BibTeX.

## Screen Mapping

The design system ships five blog screens. Each one lands on an existing or new URL.
This mapping preserves every current URL.

| Design system screen | URL | Source file |
|---|---|---|
| `ui_kits/blog/About.jsx` | `/` | `src/en/index.njk` |
| `ui_kits/blog/Home.jsx` | `/posts/` | `src/en/posts/index.njk` |
| `ui_kits/blog/Archive.jsx` | `/posts/archive/` | `src/en/posts/archive.njk` (new) |
| `ui_kits/blog/Post.jsx` | `/posts/<slug>/` | `src/_includes/layouts/post.njk` |
| `ui_kits/blog/Site.jsx` | every page | `src/_includes/layouts/layout.njk`, `nav.njk`, `footer.njk`, `searchOverlay.njk` |
| — (new) | `/preprints/` | `src/en/preprints.njk` (new) |
| Archive rows reused | `/posts/tag/<slug>/` | `src/tag/index.njk` |

`/` keeps the owner's biography. The design system About screen is exactly that shape —
prose, an "Elsewhere" list, a `whoami` terminal, and a short post list — so the
biography needs no rewrite, only new markup and the emoji removed.

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `scripts/check-build.sh` | Build-output assertion harness. Every task adds assertions here. |
| `src/styles/tty.css` | The single stylesheet templates link. `@import` list only. |
| `src/styles/tty/webfonts.css` | This site's own file. Pins the display face, which the token file leaves on a mutable tag. |
| `src/styles/tty/tokens/fonts.css` | Verbatim copy from the design system. |
| `src/styles/tty/tokens/colors.css` | Verbatim copy. |
| `src/styles/tty/tokens/typography.css` | Verbatim copy. |
| `src/styles/tty/tokens/spacing.css` | Verbatim copy. |
| `src/styles/tty/tokens/effects.css` | Verbatim copy. |
| `src/styles/tty/tokens/motion.css` | Verbatim copy. |
| `src/styles/tty/tokens/breakpoints.css` | Verbatim copy. |
| `src/styles/tty/tokens/base.css` | Verbatim copy. |
| `src/styles/tty/core.css` | Button, Tag, Badge, KeyHint, Divider, Panel, Tabs, Input, MenuList. |
| `src/styles/tty/content.css` | PostCard row, TerminalWindow, Foldout, caret, Prose wrapper. |
| `src/styles/tty/layout.css` | Page shell, nav, footer, screen grids, hero, rails, search overlay. |
| `src/styles/tty/prose.css` | Markdown body: headings, lists, quotes, tables, images, KaTeX. |
| `src/styles/tty/prism-tty.css` | Prism token colours and code-block chrome. |
| `src/_includes/tty/core.njk` | Macros: `btn`, `tag`, `badge`, `keyhint`, `divider`, `panel`. |
| `src/_includes/tty/content.njk` | Macros: `postrow`, `terminal`, `foldout`. |
| `src/_includes/nav.njk` | Sticky nav: wordmark, tab strip, `/` key hint. |
| `src/_includes/searchOverlay.njk` | The `/` search overlay markup. |
| `src/_includes/archivedBanner.njk` | Stale-content banner for an archived post. |
| `src/scripts/tty-search.js` | Search overlay behaviour and FlexSearch query. |
| `src/scripts/tty-progress.js` | Reading-progress percentage on a post page. |
| `src/scripts/tty-typewriter.js` | Hero terminal typewriter. |
| `src/scripts/tty-archive.js` | Archive sort toggle. |
| `src/en/posts/archive.njk` | The full archive index. |
| `src/en/preprints.njk` | The preprints list. |
| `src/_data/preprints.js` | Paper metadata. |

**Modified:**

| Path | Change |
|---|---|
| `.eleventy.js` | New collections, filters, passthrough copies, and two `markdown-it` rules. Dead filters removed. |
| `.github/workflows/ci.yml` | Replace the inline `test -f` block with `./scripts/check-build.sh`. |
| `devenv.nix` | Add a `check` script. |
| `src/_includes/layouts/layout.njk` | New head, new shell, Pico removed. |
| `src/_includes/layouts/post.njk` | Design system Post screen. |
| `src/_includes/footer.njk` | Design system footer. |
| `src/_includes/translationWarning.njk` | Emoji removed, new markup. |
| `src/en/index.njk` | Design system About screen, emoji removed. |
| `src/en/posts/index.njk` | Design system Home screen. |
| `src/en/contact.njk` | Design system list markup. |
| `src/en/404.njk` | Design system markup. Redirect script kept. |
| `src/tag/index.njk` | Archive row markup. |
| `src/_data/i18n/en.json` | New and renamed UI strings. |
| `CLAUDE.md` | Document the design system and the new pages. |

**Deleted:**

| Path | Reason |
|---|---|
| `src/styles/style.css` | Pico overrides. Replaced by `src/styles/tty/`. |
| `src/styles/blog.css` | Pico overrides. Replaced by `src/styles/tty/`. |
| `src/scripts/search.js` | Replaced by `src/scripts/tty-search.js`. |
| `src/_includes/header.njk` | Replaced by `nav.njk`. |
| `src/_includes/pageHeader.njk` | Replaced by `nav.njk`. |
| `src/_includes/languageDropdown.njk` | Never included by any template. Dead. |

**Untouched:** `src/_includes/structuredData.njk`, `src/_includes/languageRedirect.njk`,
`src/feed.njk`, `src/sitemap.njk`, `src/search-index.njk`, `src/tag/tag.11tydata.js`,
`lib/tagSlug.js`, `src/_data/seo.js`, every file under `src/en/posts/*.md`,
`public/**`, `preprints/*.pdf`.

## Out Of Scope

State these to the owner at the end. Do not fix them inside this migration.

- `src/_includes/structuredData.njk` still claims `"knowsLanguage": ["en","pt","es","ja"]`
  while i18n is disabled.
- `src/en/contact.njk` shows `elliancarlos@example.com`. The preprint PDF shows
  `elliancarlos@gmail.com`. Publishing a real address is the owner's call. Keep the
  current value and ask.
- `src/_data/i18n/pt.json`, `es.json`, `ja.json` stay as they are. `I18N_ENABLED` stays
  `false`.

---
### Task 1: Build-check harness

There is no unit test suite, so the assertion harness *is* the test suite. Every later
task writes its failing assertion into this script first. Build it now.

**Files:**
- Create: `scripts/check-build.sh`
- Modify: `.github/workflows/ci.yml` — the step named `Check the build output` in the
  `build` job, the one whose `run: |` block holds the `test -f dist/…` lines. The
  `devenv` job holds a step with the same name; leave that one alone. Find the step by
  name: line numbers rot, the name does not. Do not touch the `Install dependencies` or
  `Build the site` steps above it.
- Modify: `devenv.nix` — the `scripts` block (the `scripts.build.exec` and
  `scripts.clean.exec` lines) and the `enterShell` command list. Find both by name.

**Interfaces:**
- Consumes: nothing.
- Produces: five shell functions every later task calls —
  - `have <path>` — asserts the file exists.
  - `grep_in <path> <literal> <label>` — asserts the literal string appears in the file.
  - `grep_not <path> <literal> <label>` — asserts the literal string does **not** appear.
  - `count_at_least <path> <literal> <n> <label>` — asserts the literal appears `n` or
    more times.
  - `absent <path> <label>` — asserts the path does **not** exist under `dist/`.
  The script reads `dist/` only. It never builds. Run `bun run build` first.
  Every assertion reads built HTML, not template source. The build escapes the text, so
  `I've` is `I&#39;ve` in `dist/`. Grep for the escaped form.

- [ ] **Step 1: Write the failing check**

```bash
./scripts/check-build.sh
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `./scripts/check-build.sh`
Expected: FAIL with `zsh: no such file or directory: ./scripts/check-build.sh`

- [ ] **Step 3: Write the harness**

Create `scripts/check-build.sh`:

```bash
#!/usr/bin/env bash
# Asserts on an existing dist/ tree. This script never builds.
# Run `bun run build` first, then run this.
#
# Warning: `bun run build` writes into dist/. Stop the dev server
# (`bun run start`) before you build, or the two fight over dist/.

set -uo pipefail

DIST="${DIST:-dist}"
fails=0

pass() { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fails=$((fails + 1)); }

section() { printf '\n== %s\n' "$1"; }

have() {
  if [ -f "$DIST/$1" ]; then pass "file $1"; else bad "file $1 is missing"; fi
}

grep_in() {
  if [ ! -f "$DIST/$1" ]; then bad "$3 (file $1 is missing)"; return; fi
  if grep -qF -e "$2" "$DIST/$1"; then pass "$3"; else bad "$3"; fi
}

grep_not() {
  if [ ! -f "$DIST/$1" ]; then bad "$3 (file $1 is missing)"; return; fi
  if grep -qF -e "$2" "$DIST/$1"; then bad "$3"; else pass "$3"; fi
}

count_at_least() {
  if [ ! -f "$DIST/$1" ]; then bad "$4 (file $1 is missing)"; return; fi
  n=$(grep -cF -e "$2" "$DIST/$1" || true)
  if [ "$n" -ge "$3" ]; then pass "$4 ($n found)"; else bad "$4 (found $n, want $3+)"; fi
}

absent() {
  if [ -e "$DIST/$1" ]; then bad "$2 ($1 is present)"; else pass "$2"; fi
}

if [ ! -d "$DIST" ]; then
  printf 'FAIL: %s does not exist. Run `bun run build` first.\n' "$DIST"
  exit 1
fi

section "pages and feeds"
have "index.html"
have "404.html"
have "posts/index.html"
have "sitemap.xml"
have "feed.xml"
have "llms.txt"
have "search-index-en.json"
have "_headers"

# Netlify and GitHub Pages serve dist/ as plain files. Nothing in the output may
# post to a server, and no host may be asked to run code. `<form` matches real
# markup only: the build escapes `<` inside code, so a post that writes about a
# form ships `&lt;form` and does not trip the check.
# grep -r walks every page, so no shell glob is involved. `dist/**/*.html` in
# bash without `shopt -s globstar` expands to `dist/*/*.html` and misses
# dist/index.html and dist/404.html.
section "no backend"
for pat in '<form' 'formaction' 'type="email"' 'type="password"'; do
  hits=$(grep -rlF --include='*.html' -e "$pat" "$DIST" | tr '\n' ' ')
  if [ -n "$hits" ]; then bad "no '$pat' in any page ($hits)"; else pass "no '$pat' in any page"; fi
done
absent "_redirects" "no host redirect file"
absent "netlify.toml" "no host config file"
absent ".htaccess" "no server config file"
runtime=$(find "$DIST" -type f \( -name '*.php' -o -name '*.cgi' -o -name '*.rb' \
  -o -name '*.py' \) | tr '\n' ' ')
if [ -n "$runtime" ]; then bad "no server-side script ($runtime)"; else pass "no server-side script"; fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'check-build: all assertions passed\n'
  exit 0
fi
printf 'check-build: %s assertion(s) failed\n' "$fails"
exit 1
```

Make it executable:

```bash
chmod +x scripts/check-build.sh
```

- [ ] **Step 4: Run it to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 5: Wire it into CI**

In `.github/workflows/ci.yml`, replace the whole `Check the build output` step of the
`build` job (the `run: |` block with the `test -f` lines) with:

```yaml
      # There is no test suite. The build output is the proof.
      - name: Check the build output
        run: ./scripts/check-build.sh
```

Replace that one step only. After the edit, confirm the `build` job still holds
`run: bun install --frozen-lockfile` and `run: bun run build` above the check step:

```bash
grep -n "bun install --frozen-lockfile\|bun run build\|check-build.sh" .github/workflows/ci.yml
```

Expected: three lines, in that order. Delete either of the first two and the `deploy-pages`
job publishes an empty artifact to GitHub Pages while Netlify keeps building the real site,
so the two hosts diverge with a green CI.

Leave the `devenv` job's own `test -f dist/index.html` step alone — it proves the Nix
shell builds, not that the site is correct.

- [ ] **Step 6: Wire it into devenv**

In `devenv.nix`, add one line to the `scripts` block, after `scripts.clean.exec`:

```nix
  scripts.check.exec = "bun run build && ./scripts/check-build.sh";
```

Then extend the `enterShell` command list. Change the line

```
    echo "  bun run clean  - Clean dist folder"
```

so the block reads

```
    echo "  bun run clean  - Clean dist folder"
    echo "  check          - Build, then assert on dist/ (stop the dev server first)"
```

Do **not** add an `enterTest` hook. `devenv test` would build into `dist/` while
`eleventy --serve` is watching it, and the two fight.

- [ ] **Step 7: Commit**

```bash
git add scripts/check-build.sh .github/workflows/ci.yml devenv.nix
git commit -m "test: add a build-output assertion harness

The site has no unit test suite, so dist/ is the only proof a change works.
check-build.sh asserts on an existing dist/ tree and never builds, so it
cannot fight the dev server. CI calls it after its build step."
```

---

### Task 2: Vendor the design system tokens

Copy the eight token files in byte-for-byte and add the one stylesheet templates will
link. Nothing consumes them yet, so the site keeps rendering through Pico. This task is
green when the tokens reach `dist/` with their values intact.

**Files:**
- Create: `src/styles/tty/tokens/fonts.css`
- Create: `src/styles/tty/tokens/colors.css`
- Create: `src/styles/tty/tokens/typography.css`
- Create: `src/styles/tty/tokens/spacing.css`
- Create: `src/styles/tty/tokens/effects.css`
- Create: `src/styles/tty/tokens/motion.css`
- Create: `src/styles/tty/tokens/breakpoints.css`
- Create: `src/styles/tty/tokens/base.css`
- Create: `src/styles/tty/webfonts.css`
- Create: `src/styles/tty.css`
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `have`, `grep_in` from Task 1.
- Produces: the custom properties every later task reads. The names later tasks rely on:
  `--surface-root`, `--surface-panel`, `--surface-raised`, `--surface-inset`,
  `--surface-hover`, `--surface-scrim`, `--text-primary`, `--text-secondary`,
  `--text-muted`, `--text-faint`, `--text-accent`, `--text-on-accent`,
  `--border-faint`, `--border-default`, `--border-strong`, `--border-focus`,
  `--yellow`, `--yellow-bright`, `--yellow-deep`, `--yellow-dim`, `--yellow-wash`,
  `--yellow-wash-strong`, `--green`, `--cyan`, `--magenta`, `--red`, `--black-void`,
  `--grey-500`, `--grey-700`, `--status-ok`, `--status-error`, `--status-warn`,
  `--syntax-keyword`, `--syntax-string`, `--syntax-number`, `--syntax-comment`,
  `--syntax-function`, `--syntax-punct`,
  `--font-display`, `--font-body`, `--font-code`, `--font-glyph`,
  `--display-xl`, `--display-lg`, `--display-md`, `--display-sm`, `--display-xs`,
  `--text-xl`, `--text-lg`, `--text-md`, `--text-sm`, `--text-xs`,
  `--weight-medium`, `--leading-tight`, `--leading-ui`, `--leading-body`,
  `--tracking-display`, `--tracking-label`,
  `--sp-1` … `--sp-24`, `--sp-section`, `--sp-block`, `--cell-w`, `--cell-h`,
  `--control-sm`, `--control-md`, `--control-lg`, `--radius-none`, `--radius-pill`,
  `--border-w`, `--border-w-thick`, `--measure-prose`, `--measure-wide`, `--page-max`,
  `--gutter`, `--tap-min`, `--row-h`, `--row-h-dense`, `--panel-header-h`,
  `--panel-footer-h`, `--shadow-hard`, `--focus-ring`, `--glow-yellow`,
  `--texture-scanlines`, `--ease-step-2`, `--ease-step-4`, `--ease-step-8`,
  `--ease-out`, `--dur-instant`, `--dur-fast`, `--dur-base`, `--dur-slow`,
  `--blink-rate`.
  It also produces the keyframes `tty-blink`, `tty-pulse`, `tty-wipe-in`,
  `tty-wipe-up`, `tty-glitch-x`, `tty-marquee`, and the global `a`, `::selection`,
  `:focus-visible`, `h1`–`h6`, and scrollbar rules from `base.css`.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, immediately before the closing `printf '\n'` block:

```bash
section "design system tokens"
have "styles/tty.css"
have "styles/tty/tokens/colors.css"
have "styles/tty/tokens/fonts.css"
have "styles/tty/tokens/typography.css"
have "styles/tty/tokens/spacing.css"
have "styles/tty/tokens/effects.css"
have "styles/tty/tokens/motion.css"
have "styles/tty/tokens/breakpoints.css"
have "styles/tty/tokens/base.css"
grep_in "styles/tty/tokens/colors.css" "--yellow: #FFD400" "signal yellow is defined"
grep_in "styles/tty/tokens/colors.css" "--surface-root: var(--black-000)" "root surface is defined"
grep_in "styles/tty/tokens/typography.css" '"Silkscreen"' "Silkscreen is the display face"
grep_in "styles/tty/tokens/typography.css" '"JetBrains Mono"' "JetBrains Mono is the body face"
grep_in "styles/tty/tokens/spacing.css" "--measure-prose: 68ch" "reading measure is 68ch"
grep_in "styles/tty/tokens/motion.css" "steps(2, end)" "stepped easing is defined"
grep_in "styles/tty/tokens/base.css" "-webkit-font-smoothing: none" "the pixel face is not smoothed"
grep_in "styles/tty/tokens/breakpoints.css" "max-width: 1279.98px" "the compact edge is 1280px"
grep_in "styles/tty.css" '@import "tty/tokens/colors.css"' "the entry stylesheet imports the tokens"
have "styles/tty/webfonts.css"
grep_in "styles/tty.css" '@import "tty/webfonts.css"' "the entry stylesheet loads the pinned display face"
grep_in "styles/tty/webfonts.css" "silkscreen@5.3.0" "the display face is pinned to one version"
grep_not "styles/tty/webfonts.css" "@latest" "no mutable font tag ships"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `file styles/tty.css is missing` and nine more missing-file lines.

- [ ] **Step 3: Copy the token files in**

The archive is at `/local/home/ellianco/Projects/TTY Design System.zip`. Extract it to a
scratch directory and copy the eight files with no edit:

```bash
mkdir -p /tmp/tty-ds && \
  unzip -o -q "/local/home/ellianco/Projects/TTY Design System.zip" -d /tmp/tty-ds && \
  mkdir -p src/styles/tty/tokens && \
  cp /tmp/tty-ds/tokens/fonts.css \
     /tmp/tty-ds/tokens/colors.css \
     /tmp/tty-ds/tokens/typography.css \
     /tmp/tty-ds/tokens/spacing.css \
     /tmp/tty-ds/tokens/effects.css \
     /tmp/tty-ds/tokens/motion.css \
     /tmp/tty-ds/tokens/breakpoints.css \
     /tmp/tty-ds/tokens/base.css \
     src/styles/tty/tokens/
```

Verify the copy with `wc -l src/styles/tty/tokens/*.css`. Expected line counts:
`base.css` 44, `breakpoints.css` 84, `colors.css` 82, `effects.css` 25, `fonts.css` 37,
`motion.css` 40, `spacing.css` 39, `typography.css` 41.

Do not reformat these files. They are the upstream source of truth. Prettier is not run
over `src/styles/tty/tokens/`.

- [ ] **Step 4: Pin the display face**

`tokens/fonts.css` fetches Silkscreen from the jsdelivr `@latest` tag. `@latest` is
mutable. The day that path moves, every heading, every panel title and the wordmark fall
back to `ui-monospace`, on both hosts, and no build fails. The token file must stay
verbatim, so pin the two faces in a file of this site's own.

Create `src/styles/tty/webfonts.css`:

```css
/* Silkscreen, pinned.

   tokens/fonts.css declares this family against silkscreen@latest. Two @font-face
   rules with the same family, weight and style resolve to the last one declared,
   and tty.css imports this file after the tokens, so these two rules win.

   5.3.0 is the fontsource version @latest resolved to on 2026-09-21. Every other
   third-party reference on this site is pinned the same way: katex@0.16.47,
   flexsearch@0.7.31. JetBrains Mono needs no override — the token file already
   pins it at jetbrains-mono:vf@5.3.0. */
@font-face {
  font-family: "Silkscreen";
  src: url("https://cdn.jsdelivr.net/fontsource/fonts/silkscreen@5.3.0/latin-400-normal.woff2") format("woff2");
  font-weight: 400;
  font-style: normal;
  font-display: swap;
}
@font-face {
  font-family: "Silkscreen";
  src: url("https://cdn.jsdelivr.net/fontsource/fonts/silkscreen@5.3.0/latin-700-normal.woff2") format("woff2");
  font-weight: 700;
  font-style: normal;
  font-display: swap;
}
```

Confirm both pinned files answer:

```bash
for w in 400 700; do
  curl -sS -o /dev/null -w "$w %{http_code} %{size_download}\n" \
    "https://cdn.jsdelivr.net/fontsource/fonts/silkscreen@5.3.0/latin-$w-normal.woff2"
done
```

Expected: `400 200 8404` and `700 200 7524`. A `404`, or a size under 1000, means the
version is wrong. Read `https://api.fontsource.org/v1/fonts/silkscreen` for the current
`npmVersion` and use that number instead.

Now create `src/styles/tty.css`:

```css
/* TTY — the one stylesheet every template links.
   Import order matters: tokens, then components, then layout, then long-form
   prose, then syntax highlighting. Later files read the earlier ones' custom
   properties, and later rules win on equal specificity.

   tty/tokens/ is a verbatim copy of the design system. Do not edit those eight
   files; re-copy them from the archive when the system ships a new version.
   Everything outside tty/tokens/ is this site's port of the React components.

   Every `@import` must stay above every rule in this file. CSS drops an
   `@import` that follows a rule. */
@import "tty/tokens/fonts.css";
@import "tty/webfonts.css";
@import "tty/tokens/colors.css";
@import "tty/tokens/typography.css";
@import "tty/tokens/spacing.css";
@import "tty/tokens/effects.css";
@import "tty/tokens/motion.css";
@import "tty/tokens/breakpoints.css";
@import "tty/tokens/base.css";
```

The `core.css`, `content.css`, `layout.css`, `prose.css`, and `prism-tty.css` imports
come in Tasks 3, 4, 5, and 6. `src/styles` already has a passthrough copy in
`.eleventy.js:99`, so no build change is needed.

- [ ] **Step 5: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 6: Confirm nothing else moved**

Run: `git status --short dist 2>/dev/null; git -P diff --stat`
Expected: only the ten new stylesheet files and `scripts/check-build.sh` changed. The
rendered pages are untouched, because no template links `tty.css` yet.

- [ ] **Step 7: Commit**

```bash
git add src/styles/tty.css src/styles/tty/webfonts.css src/styles/tty/tokens \
  scripts/check-build.sh
git commit -m "feat(design): vendor the TTY design system tokens

Eight token files copied byte-for-byte from the design system archive, plus
the entry stylesheet templates will link. webfonts.css pins Silkscreen to
silkscreen@5.3.0, because the token file points at the mutable @latest tag and
must stay verbatim. No template consumes any of this yet, so the rendered pages
do not change."
```

---
### Task 3: Port the core components

Nine React components become CSS classes plus Nunjucks macros: Button, Tag, Badge,
KeyHint, Divider, Panel, Tabs, Input, MenuList. Read each component's source under
`/tmp/tty-ds/components/` if you want the original inline styles; the CSS below is the
faithful port and is what you write.

**Read this before you start.** The design system `readme.md` states two rules the
shipped components break. Item 1 keeps the component. Item 2 keeps the readme:

1. The prose says Silkscreen is "never set below 15px". `Divider` uses 12px,
   `Panel` 13px, `PostCard` 13px, `MenuList` section labels 11px. The 15px floor applies
   to the display *scale* (`--display-xs`), not to chrome labels. Keep the component
   values. Do not "fix" them upward. The CSS below writes the 11px and 13px ones as
   `--text-xs` and `--text-sm`, which hold exactly those values on every screen.
2. The prose says every target clears 44px on touch. `Tag.jsx` is a flat 22px. Under
   1280px the port drops the fixed height and reads `--tap-min` instead. That token is
   not a number this plan invents: `tokens/breakpoints.css` resolves it to 44px for a
   coarse pointer and 32px for a fine pointer in a narrow window, which is the same rule
   the control heights follow. So the chip is 44px on a phone, 32px for a mouse, and
   22px on the desktop layout, where `Tag.jsx` is unchanged. With the token the readme's
   44px rule holds, so this is a deviation from the component only, not from the system.

Two smaller divergences from the components, also on purpose:

3. `.tty-panel--accent` carries the yellow-wash head and yellow title that `Panel.jsx`
   gives its `focused` state. `tone="accent"` only turns the border yellow there. This
   site never focuses a panel, so the two states merge into one modifier.
4. `.tty-menu__item:hover` lifts the label to `--text-primary` and `.tty-tag--on:hover`
   brightens the selected chip. `MenuList.jsx` changes only the background on hover and
   `Tag.jsx` draws no hover state over a selected chip. A pointer needs the feedback.

**Files:**
- Create: `src/styles/tty/core.css`
- Create: `src/_includes/tty/core.njk`
- Modify: `src/styles/tty.css`
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: every custom property listed in Task 2.
- Produces the CSS classes: `.tty-btn` (`--primary`, `--ghost`, `--sm`, `--lg`,
  `--block`), `.tty-tag` (`--on`, `.tty-tag__count`), `.tty-badge` (`--outline`,
  `--accent`, `--ok`, `--info`, `--warn`, `--error`, `--special`), `.tty-keyhint`
  (`--accent`, `.tty-keyhint__label`), `.tty-rule`, `.tty-divider`
  (`.tty-divider__label`, `.tty-divider__line`), `.tty-panel` (`--accent`, `--flush`,
  `.tty-panel__head`, `.tty-panel__title`, `.tty-panel__sub`, `.tty-panel__body`,
  `.tty-panel__foot`), `.tty-tabs` (`.tty-tabs__tab`, `.tty-tabs__count`), `.tty-input`
  (`--lg`, `.tty-input__prefix`), `.tty-menu` (`--dense`, `.tty-menu__item`,
  `.tty-menu__cursor`, `.tty-menu__glyph`, `.tty-menu__label`, `.tty-menu__hint`,
  `.tty-menu__section`), `.tty-spacer`.
- Produces the Nunjucks macros in `src/_includes/tty/core.njk`, imported by later tasks as
  `{% import "tty/core.njk" as tty %}`:
  - `tty.btn(label, href, tone="", size="")` → `<a class="tty-btn …">`. `tone` is `""`,
    `"primary"`, or `"ghost"`. `size` is `""`, `"sm"`, or `"lg"`.
  - `tty.tag(label, href, count=null, on=false)` → `<a class="tty-tag …">`.
  - `tty.badge(label, tone="", outline=false)` → `<span class="tty-badge …">`.
  - `tty.keyhint(keys, label="", tone="")` → `<span class="tty-keyhint">`. `keys` is a
    list of strings.
  - `tty.divider(label)` → `<div class="tty-divider">`.
  - `tty.panel(title, sub="", cls="")` → a `{% call %}` macro. The body goes in
    `.tty-panel__body`.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "core components"
have "styles/tty/core.css"
grep_in "styles/tty.css" '@import "tty/core.css"' "the entry stylesheet imports core.css"
grep_in "styles/tty/core.css" ".tty-btn--primary" "the primary button exists"
grep_in "styles/tty/core.css" ".tty-tag--on" "the selected tag exists"
grep_in "styles/tty/core.css" ".tty-badge--outline" "the outline badge exists"
grep_in "styles/tty/core.css" ".tty-keyhint kbd" "the key cap exists"
grep_in "styles/tty/core.css" ".tty-divider__label" "the divider label exists"
grep_in "styles/tty/core.css" ".tty-panel__title" "the panel title exists"
grep_in "styles/tty/core.css" '.tty-tabs__tab[aria-current="page"]' "the active tab exists"
grep_in "styles/tty/core.css" ".tty-input:focus-within" "the input focus state exists"
grep_in "styles/tty/core.css" ".tty-menu__cursor" "the menu cursor exists"
grep_not "styles/tty/core.css" "border-radius: 4px" "no rounded corner slips into core.css"
grep_not "styles/tty/core.css" "box-shadow: 0 2px" "no soft shadow slips into core.css"
count_at_least "styles/tty/core.css" "-webkit-font-smoothing: none" 3 "every Silkscreen rule disables smoothing"
grep_in "styles/tty/core.css" ".tty-tabs__tab:focus-visible" "the focused tab draws its ring inside the scroll container"
grep_in "styles/tty/core.css" ".tty-tag { height: var(--tap-min)" "the tag reads the touch-target token"
grep_not "styles/tty/core.css" "height: 32px" "no hard-coded touch target in core.css"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `file styles/tty/core.css is missing` plus sixteen dependent failures.

- [ ] **Step 3: Write the core component CSS**

Create `src/styles/tty/core.css`:

```css
/* TTY core components — ported from components/core/, components/forms/Input.jsx,
   and components/navigation/Tabs.jsx + MenuList.jsx.
   The React originals carry inline styles; these are the same values as classes.

   Note on link resets: tokens/base.css gives every `a` a dim-yellow bottom border.
   Any component rendered as an `<a>` sets its own `border` and therefore overrides
   it on specificity. The explicit `:hover` rules below beat base.css's
   `a:hover { border-bottom-color: … }` because core.css is imported after it. */

.tty-spacer { flex: 1 1 auto; }

/* ── Button ─────────────────────────────────────────────────────────────── */
.tty-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--sp-2);
  height: var(--control-md);
  padding: 0 14px;
  font: var(--weight-medium) var(--text-sm)/1 var(--font-body);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--text-primary);
  background: transparent;
  border: var(--border-w) solid var(--border-strong);
  border-radius: var(--radius-none);
  cursor: pointer;
  white-space: nowrap;
  text-decoration: none;
  transition: background var(--dur-fast) var(--ease-out),
              color var(--dur-fast) var(--ease-out),
              border-color var(--dur-fast) var(--ease-out);
}
.tty-btn:hover {
  color: var(--text-primary);
  background: var(--surface-hover);
  border-color: var(--border-strong);
}
/* Press nudges one pixel down-right; the key travels. */
.tty-btn:active { transform: translate(1px, 1px); }
.tty-btn[aria-disabled="true"],
.tty-btn:disabled {
  color: var(--text-faint);
  background: var(--surface-raised);
  border-color: var(--border-faint);
  cursor: not-allowed;
  transform: none;
}

.tty-btn--primary {
  color: var(--text-on-accent);
  background: var(--yellow);
  border-color: var(--yellow);
}
.tty-btn--primary:hover {
  color: var(--text-on-accent);
  background: var(--yellow-bright);
  border-color: var(--yellow-bright);
}

.tty-btn--ghost {
  color: var(--text-secondary);
  border-color: transparent;
}
.tty-btn--ghost:hover {
  color: var(--text-primary);
  background: var(--surface-raised);
  border-color: transparent;
}

.tty-btn--sm { height: var(--control-sm); padding: 0 10px; font-size: var(--text-xs); }
.tty-btn--lg { height: var(--control-lg); padding: 0 20px; font-size: var(--text-md); }
.tty-btn--block { display: flex; width: 100%; }

/* ── Tag ────────────────────────────────────────────────────────────────── */
.tty-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 22px;
  padding: 0 var(--sp-2);
  font: var(--text-xs)/1 var(--font-body);
  color: var(--text-secondary);
  background: var(--surface-raised);
  border: var(--border-w) solid var(--border-faint);
  border-radius: var(--radius-none);
  text-decoration: none;
  white-space: nowrap;
  transition: background var(--dur-fast) var(--ease-out),
              color var(--dur-fast) var(--ease-out),
              border-color var(--dur-fast) var(--ease-out);
}
.tty-tag::before { content: "#"; opacity: 0.5; }
.tty-tag:hover {
  color: var(--yellow);
  background: var(--yellow-wash);
  border-color: var(--border-faint);
}
.tty-tag__count { opacity: 0.6; }

.tty-tag--on {
  color: var(--text-on-accent);
  background: var(--yellow);
  border-color: var(--yellow);
}
.tty-tag--on:hover {
  color: var(--text-on-accent);
  background: var(--yellow-bright);
  border-color: var(--yellow-bright);
}

/* Deliberate deviation: the React Tag is a flat 22px. Under 1280px the target
   reads --tap-min, so a finger gets 44px and a mouse in a narrow window keeps
   32px. See the note at the head of Task 3. */
@media (max-width: 1279.98px) {
  .tty-tag { height: var(--tap-min); padding: 0 10px; font-size: var(--text-sm); }
}

/* ── Badge ──────────────────────────────────────────────────────────────── */
.tty-badge {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 18px;
  padding: 0 6px;
  font: var(--weight-medium) var(--text-xs)/1 var(--font-body);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--text-on-accent);
  background: var(--grey-700);
  border: var(--border-w) solid var(--grey-700);
  border-radius: var(--radius-none);
  white-space: nowrap;
}
.tty-badge--outline { color: var(--grey-700); background: transparent; }

.tty-badge--accent { background: var(--yellow); border-color: var(--yellow); }
.tty-badge--accent.tty-badge--outline { color: var(--yellow); background: transparent; }
.tty-badge--ok { background: var(--status-ok); border-color: var(--status-ok); }
.tty-badge--ok.tty-badge--outline { color: var(--status-ok); background: transparent; }
.tty-badge--info { background: var(--status-info); border-color: var(--status-info); }
.tty-badge--info.tty-badge--outline { color: var(--status-info); background: transparent; }
.tty-badge--warn { background: var(--status-warn); border-color: var(--status-warn); }
.tty-badge--warn.tty-badge--outline { color: var(--status-warn); background: transparent; }
.tty-badge--error { background: var(--status-error); border-color: var(--status-error); }
.tty-badge--error.tty-badge--outline { color: var(--status-error); background: transparent; }
.tty-badge--special { background: var(--status-special); border-color: var(--status-special); }
.tty-badge--special.tty-badge--outline { color: var(--status-special); background: transparent; }

/* ── KeyHint ────────────────────────────────────────────────────────────── */
.tty-keyhint { display: inline-flex; align-items: center; gap: 6px; }
.tty-keyhint__keys { display: inline-flex; gap: 3px; }
.tty-keyhint kbd {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 4px;
  font: var(--text-xs)/1 var(--font-body);
  color: var(--text-secondary);
  background: var(--surface-raised);
  border: var(--border-w) solid var(--border-default);
  border-radius: var(--radius-none);
}
.tty-keyhint__label { font-size: var(--text-xs); color: var(--text-faint); }
.tty-keyhint--accent kbd {
  color: var(--text-on-accent);
  background: var(--yellow);
  border-color: var(--yellow);
}

/* ── Divider ────────────────────────────────────────────────────────────── */
.tty-rule {
  border: 0;
  border-top: var(--border-w) solid var(--border-faint);
  margin: 0;
}
.tty-divider { display: flex; align-items: center; gap: 10px; }
.tty-divider__label {
  font-family: var(--font-display);
  font-size: 12px;
  letter-spacing: var(--tracking-label);
  text-transform: uppercase;
  color: var(--text-faint);
  -webkit-font-smoothing: none;
  font-smooth: never;
}
.tty-divider__line {
  flex: 1;
  border-top: var(--border-w) solid var(--border-faint);
}

/* ── Panel ──────────────────────────────────────────────────────────────── */
.tty-panel {
  display: flex;
  flex-direction: column;
  min-height: 0;
  background: var(--surface-panel);
  border: var(--border-w) solid var(--border-default);
  border-radius: var(--radius-none);
  transition: border-color var(--dur-fast) var(--ease-out);
}
.tty-panel__head {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: none;
  min-height: var(--panel-header-h);
  padding: 0 10px;
  border-bottom: var(--border-w) solid var(--border-default);
  background: var(--surface-raised);
}
.tty-panel__title {
  font-family: var(--font-display);
  font-size: var(--text-sm);
  letter-spacing: var(--tracking-label);
  text-transform: uppercase;
  color: var(--text-secondary);
  -webkit-font-smoothing: none;
  font-smooth: never;
}
.tty-panel__sub { font-size: var(--text-xs); color: var(--text-faint); }
.tty-panel__body { flex: 1; min-height: 0; padding: var(--sp-4); }
.tty-panel__foot {
  flex: none;
  min-height: var(--panel-footer-h);
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  padding: 4px 10px;
  border-top: var(--border-w) solid var(--border-faint);
  font-size: var(--text-xs);
  color: var(--text-faint);
}
.tty-panel--accent { border-color: var(--yellow); }
.tty-panel--accent .tty-panel__head {
  border-bottom-color: var(--yellow);
  background: var(--yellow-wash);
}
.tty-panel--accent .tty-panel__title { color: var(--yellow); }
.tty-panel--flush .tty-panel__body { padding: 0; }

/* ── Tabs (underline variant) ───────────────────────────────────────────── */
.tty-tabs {
  display: flex;
  align-items: stretch;
  gap: 0;
  max-width: 100%;
  overflow-x: auto;
  scrollbar-width: none;
  border-bottom: var(--border-w) solid var(--border-default);
}
.tty-tabs::-webkit-scrollbar { display: none; }
.tty-tabs__tab {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  flex: none;
  min-height: var(--tap-min);
  padding: 0 12px;
  font: var(--text-xs)/1 var(--font-body);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-muted);
  background: transparent;
  border: 0;
  border-bottom: var(--border-w-thick) solid transparent;
  margin-bottom: -1px;
  cursor: pointer;
  text-decoration: none;
  transition: color var(--dur-fast) var(--ease-out),
              border-color var(--dur-fast) var(--ease-out);
}
.tty-tabs__tab:hover {
  color: var(--text-primary);
  border-bottom-color: var(--border-strong);
}
.tty-tabs__tab[aria-current="page"],
.tty-tabs__tab[aria-selected="true"] {
  color: var(--yellow);
  border-bottom-color: var(--yellow);
}
.tty-tabs__count { opacity: 0.6; }
/* .tty-tabs is a scroll container: `overflow-x: auto` makes `overflow-y` compute
   to `auto` too, so the outset `--focus-ring` box-shadow base.css puts on a
   focused tab is clipped at the top and bottom edges of the strip, and
   `scrollbar-width: none` hides every sign of it. Draw the ring inside the tab
   instead. A negative `outline-offset` paints the outline within the border box,
   where no scroll container can cut it, and the strip still scrolls sideways. */
.tty-tabs__tab:focus-visible {
  box-shadow: none;
  outline: var(--border-w-thick) solid var(--yellow);
  outline-offset: calc(var(--border-w-thick) * -1);
}

/* ── Input ──────────────────────────────────────────────────────────────── */
.tty-input {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  height: var(--control-md);
  padding: 0 10px;
  background: var(--surface-inset);
  border: var(--border-w) solid var(--border-default);
  border-radius: var(--radius-none);
  transition: border-color var(--dur-fast) var(--ease-out);
}
.tty-input:focus-within {
  border-color: var(--yellow);
  box-shadow: 0 0 0 1px var(--yellow-wash-strong);
}
.tty-input--lg { height: var(--control-lg); }
.tty-input__prefix {
  flex: none;
  font-family: var(--font-glyph);
  font-size: var(--text-sm);
  color: var(--text-faint);
}
.tty-input:focus-within .tty-input__prefix { color: var(--yellow); }
.tty-input input {
  flex: 1;
  min-width: 0;
  height: 100%;
  margin: 0;
  padding: 0;
  border: 0;
  outline: none;
  background: transparent;
  color: var(--text-primary);
  font: var(--text-sm)/1 var(--font-body);
}
.tty-input input::placeholder { color: var(--text-faint); opacity: 1; }
/* The wrapper owns the focus language, so the inner field must not draw a ring
   of its own on top of it. */
.tty-input input:focus-visible { box-shadow: none; }
.tty-input input[type="search"]::-webkit-search-cancel-button { display: none; }

/* ── MenuList ───────────────────────────────────────────────────────────── */
.tty-menu { list-style: none; margin: 0; padding: 0; }
.tty-menu__item {
  display: flex;
  align-items: center;
  gap: 9px;
  width: 100%;
  min-height: var(--row-h);
  padding: 0 10px;
  font-size: var(--text-sm);
  color: var(--text-secondary);
  background: transparent;
  border: 0;
  border-radius: var(--radius-none);
  text-align: left;
  text-decoration: none;
  cursor: pointer;
}
/* Dense is a desktop density. `MenuList` is used as `dense={!bp.compact}` in both
   Archive.jsx and About.jsx, so the modifier must not reach a compact screen. The
   media query here is what enforces that, so a template can carry
   `tty-menu--dense` at every width — which is what the archive rail and the
   homepage rail do. Under 1280px the row falls back to `--row-h`: 44px for a
   finger, 32px for a fine pointer. */
@media (min-width: 1280px) {
  .tty-menu--dense .tty-menu__item { min-height: var(--row-h-dense); }
}
.tty-menu__item:hover { color: var(--text-primary); background: var(--surface-hover); }
/* A focused row draws its ring inside its own box. `.tty-search__panel` is
   `overflow: auto`, and the outset `--focus-ring` box-shadow is ink overflow,
   which a scroll container clips — the same defect as the tab strip above. An
   outline with a negative offset paints inside the border box, where nothing can
   cut it. A selected row is a yellow bar, so its ring turns black to stay
   visible. */
.tty-menu__item:focus-visible {
  box-shadow: none;
  outline: var(--border-w-thick) solid var(--yellow);
  outline-offset: calc(var(--border-w-thick) * -1);
}
.tty-menu__item[aria-selected="true"]:focus-visible,
.tty-menu__item.is-on:focus-visible { outline-color: var(--black-void); }
/* Selection is a full-width yellow bar with black text — the TUI list idiom. */
.tty-menu__item[aria-selected="true"],
.tty-menu__item.is-on {
  color: var(--text-on-accent);
  background: var(--yellow);
}
.tty-menu__cursor {
  flex: none;
  width: 8px;
  font-family: var(--font-glyph);
  opacity: 0;
}
.tty-menu__item:hover .tty-menu__cursor { opacity: 0.5; }
.tty-menu__item[aria-selected="true"] .tty-menu__cursor,
.tty-menu__item.is-on .tty-menu__cursor { opacity: 1; }
.tty-menu__glyph {
  flex: none;
  width: 14px;
  font-family: var(--font-glyph);
  opacity: 0.7;
}
.tty-menu__label {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tty-menu__hint { flex: none; font-size: var(--text-xs); opacity: 0.45; }
.tty-menu__item[aria-selected="true"] .tty-menu__hint,
.tty-menu__item.is-on .tty-menu__hint { opacity: 0.7; }
.tty-menu__section {
  padding: 10px 10px 4px;
  font-family: var(--font-display);
  font-size: var(--text-xs);
  letter-spacing: var(--tracking-label);
  text-transform: uppercase;
  color: var(--text-faint);
  -webkit-font-smoothing: none;
  font-smooth: never;
}
```

- [ ] **Step 4: Write the core macros**

Create `src/_includes/tty/core.njk`:

```njk
{#
  TTY core macros. Import as:  {% import "tty/core.njk" as tty %}

  Every macro renders the classes defined in /styles/tty/core.css. Keep the two
  files in step: a class that appears here must exist there.
#}

{% macro btn(label, href, tone="", size="") %}
<a class="tty-btn{% if tone %} tty-btn--{{ tone }}{% endif %}{% if size %} tty-btn--{{ size }}{% endif %}" href="{{ href }}">{{ label }}</a>
{%- endmacro %}

{% macro tag(label, href, count=null, on=false) %}
<a class="tty-tag{% if on %} tty-tag--on{% endif %}" href="{{ href }}">{{ label }}{% if count != null %}<span class="tty-tag__count">{{ count }}</span>{% endif %}</a>
{%- endmacro %}

{% macro badge(label, tone="", outline=false) %}
<span class="tty-badge{% if tone %} tty-badge--{{ tone }}{% endif %}{% if outline %} tty-badge--outline{% endif %}">{{ label }}</span>
{%- endmacro %}

{% macro keyhint(keys, label="", tone="") %}
<span class="tty-keyhint{% if tone %} tty-keyhint--{{ tone }}{% endif %}"><span class="tty-keyhint__keys">{% for k in keys %}<kbd>{{ k }}</kbd>{% endfor %}</span>{% if label %}<span class="tty-keyhint__label">{{ label }}</span>{% endif %}</span>
{%- endmacro %}

{% macro divider(label) %}
<div class="tty-divider"><span class="tty-divider__label">{{ label }}</span><span class="tty-divider__line"></span></div>
{%- endmacro %}

{#
  panel() takes its body through caller(), so call it with {% call %}:

    {% call tty.panel("feeds", "3 endpoints") %}
      <p>…</p>
    {% endcall %}
#}
{% macro panel(title, sub="", cls="") %}
<section class="tty-panel{% if cls %} {{ cls }}{% endif %}">
  <header class="tty-panel__head">
    <span class="tty-panel__title">{{ title }}</span>
    {% if sub %}<span class="tty-panel__sub">{{ sub }}</span>{% endif %}
  </header>
  <div class="tty-panel__body">{{ caller() }}</div>
</section>
{%- endmacro %}
```

- [ ] **Step 5: Add the import**

In `src/styles/tty.css`, add one line after the `tty/tokens/base.css` import:

```css
@import "tty/core.css";
```

- [ ] **Step 6: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 7: Commit**

```bash
git add src/styles/tty/core.css src/styles/tty.css src/_includes/tty/core.njk scripts/check-build.sh
git commit -m "feat(design): port the TTY core components to CSS and macros

Button, Tag, Badge, KeyHint, Divider, Panel, Tabs, Input and MenuList move
from React inline styles to classes plus Nunjucks macros. The documented
deviations: chrome labels keep their sub-15px Silkscreen sizes, and Tag reads
--tap-min under 1280px, so a finger gets 44px and a mouse keeps 32px."
```

---
### Task 4: Port the content components

Five more components: PostCard (as a row), TerminalWindow, Foldout, CursorBlink, and the
Prose wrapper. The Foldout drops its React state and becomes a native `<details>`, so the
compact filter rail needs no JavaScript.

**Files:**
- Create: `src/styles/tty/content.css`
- Create: `src/_includes/tty/content.njk`
- Modify: `src/styles/tty.css`
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: the tokens from Task 2 and `.tty-badge`, `.tty-badge--outline`,
  `.tty-badge--warn` from Task 3.
- Produces the CSS classes: `.tty-postrow` (`.tty-postrow__index`,
  `.tty-postrow__body`, `.tty-postrow__title`, `.tty-postrow__excerpt`,
  `.tty-postrow__tags`, `.tty-postrow__meta`), `.tty-term` (`.tty-term__bar`,
  `.tty-term__tab`, `.tty-term__dots`, `.tty-term__dot` with `--r`/`--y`/`--g`,
  `.tty-term__name`, `.tty-term__body`, `.tty-term__line`, `.tty-term__prompt`,
  `.tty-term__out`, `.tty-term__path`), `.tty-foldout` (`.tty-foldout__summary`,
  `.tty-foldout__hint`, `.tty-foldout__body`), `.tty-caret` (`--bar`), `.tty-prose`
  (`--wide`, `--md`).
- Produces the figure breakout rules in `content.css`. At 1280px and up a figure leaves
  the 68ch prose measure and grows to the wide measure; at 1440px and up it grows to the
  page column. The selectors match the markup the 15 figures in the posts already carry,
  so no post is edited.
- Produces the Nunjucks macros in `src/_includes/tty/content.njk`, imported as
  `{% import "tty/content.njk" as ttyc %}`:
  - `ttyc.postrow(post, index, archived=false)` → one `<a class="tty-postrow">`. `post`
    is an Eleventy collection item. `index` is the already-padded string from the
    `postIndexes` filter added in Task 7. `archived` adds the `archived` badge.
  - `ttyc.terminal(name, chrome="tab")` → a `{% call %}` macro. `chrome` is `"tab"` or
    `"dots"`. The body goes in `.tty-term__body`.
  - `ttyc.foldout(label, hint="")` → a `{% call %}` macro over `<details>`.
- Depends on the `postDate` filter (already in `.eleventy.js:320`) and on the
  `readingTime` filter, which Task 7 adds. Until Task 8 lands, `post | readingTime`
  renders nothing and Eleventy throws `filter not found: readingTime`. So **this task's
  macro file must not be rendered by any template yet** — it is imported first in Task 9.
  That is why Task 4's assertions read the CSS, not the HTML.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "content components"
have "styles/tty/content.css"
grep_in "styles/tty.css" '@import "tty/content.css"' "the entry stylesheet imports content.css"
grep_in "styles/tty/content.css" ".tty-postrow:hover .tty-postrow__title" "the post row hover state exists"
grep_in "styles/tty/content.css" "border-left-color: var(--yellow)" "the post row grows a yellow left rule on hover"
grep_in "styles/tty/content.css" "var(--texture-scanlines)" "the terminal carries the scanline texture"
grep_in "styles/tty/content.css" "box-shadow: var(--shadow-hard)" "the terminal uses the hard offset block"
grep_in "styles/tty/content.css" 'content: "▾"' "the open foldout marker exists"
grep_in "styles/tty/content.css" "animation: tty-blink" "the caret blinks"
grep_in "styles/tty/content.css" "max-width: var(--measure-prose)" "prose holds the 68ch measure"
grep_in "styles/tty/content.css" 'div[style*="justify-content: center"]' "a centred figure breaks out of the prose measure"
grep_in "styles/tty/content.css" "p:has(> img:only-child)" "a plain Markdown image breaks out too"
grep_not "styles/tty/content.css" "border-radius: 4px" "no rounded corner slips into content.css"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `file styles/tty/content.css is missing` plus eleven dependent failures.

- [ ] **Step 3: Write the content component CSS**

Create `src/styles/tty/content.css`:

```css
/* TTY content components — ported from components/content/ and
   components/motion/CursorBlink.jsx.

   PostCard becomes one `<a class="tty-postrow">` so the whole row is a single
   link with a single tab stop. The React version nests no links either: tags
   inside a row are plain text, and the linked tags live in the filter rail. */

/* ── PostCard, row variant ──────────────────────────────────────────────── */
.tty-postrow {
  display: flex;
  gap: 18px;
  padding: 14px;
  color: inherit;
  background: transparent;
  text-decoration: none;
  border: 0;
  border-top: var(--border-w) solid var(--border-faint);
  border-left: var(--border-w-thick) solid transparent;
  transition: background var(--dur-fast) var(--ease-out),
              border-color var(--dur-fast) var(--ease-out);
}
.tty-postrow:hover {
  background: var(--surface-raised);
  border-left-color: var(--yellow);
}
.tty-postrow__index {
  flex: none;
  width: 34px;
  font-family: var(--font-display);
  font-size: var(--text-sm);
  color: var(--text-faint);
  -webkit-font-smoothing: none;
  font-smooth: never;
  transition: color var(--dur-fast) var(--ease-out);
}
.tty-postrow:hover .tty-postrow__index { color: var(--yellow); }
.tty-postrow__body { flex: 1; min-width: 0; }
.tty-postrow__title {
  margin: 0;
  font-family: var(--font-display);
  font-size: 17px;
  line-height: var(--leading-tight);
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--text-primary);
  -webkit-font-smoothing: none;
  font-smooth: never;
  transition: color var(--dur-fast) var(--ease-out);
}
.tty-postrow:hover .tty-postrow__title { color: var(--yellow); }
.tty-postrow__excerpt {
  margin: 7px 0 0;
  font-size: var(--text-sm);
  line-height: 1.6;
  color: var(--text-muted);
  text-wrap: pretty;
}
.tty-postrow__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 10px;
  font-size: var(--text-xs);
  color: var(--text-faint);
}
.tty-postrow__meta {
  flex: none;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
  font-size: var(--text-xs);
  color: var(--text-faint);
  white-space: nowrap;
}

/* On a phone the meta column squeezes the title, so it drops under the body. */
@media (max-width: 430px) {
  .tty-postrow { flex-wrap: wrap; gap: 10px; }
  .tty-postrow__meta {
    flex-direction: row;
    align-items: center;
    gap: 10px;
    width: 100%;
    padding-left: 34px;
  }
}

/* ── TerminalWindow ─────────────────────────────────────────────────────── */
.tty-term {
  position: relative;
  display: flex;
  flex-direction: column;
  background: var(--surface-inset);
  border: var(--border-w) solid var(--border-default);
  border-radius: var(--radius-none);
  box-shadow: var(--shadow-hard);
  overflow: hidden;
}
/* The CRT suggestion sits above the transcript and below the pointer. */
.tty-term::after {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--texture-scanlines);
}
.tty-term__bar {
  flex: none;
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  height: 28px;
  padding: 0 10px;
  background: var(--surface-raised);
  border-bottom: var(--border-w) solid var(--border-default);
}
.tty-term__tab {
  padding: 2px var(--sp-2);
  font-size: var(--text-xs);
  color: var(--yellow);
  background: var(--black-void);
  border: var(--border-w) solid var(--border-default);
}
.tty-term__dots { display: flex; gap: 5px; }
.tty-term__dot { width: 8px; height: 8px; }
.tty-term__dot--r { background: var(--red); }
.tty-term__dot--y { background: var(--yellow); }
.tty-term__dot--g { background: var(--green); }
.tty-term__name { flex: 1; font-size: var(--text-xs); color: var(--text-faint); }
.tty-term__name--center { text-align: center; }
.tty-term__body {
  flex: 1;
  min-height: 0;
  padding: var(--sp-4);
  font-family: var(--font-code);
  font-size: var(--text-sm);
  line-height: 1.65;
  overflow: auto;
}
.tty-term__line { display: flex; gap: 12px; }
.tty-term__prompt { color: var(--green); }
.tty-term__out { color: var(--text-muted); }
.tty-term__path { color: var(--cyan); }
.tty-term__date { color: var(--text-faint); }

/* ── CursorBlink ────────────────────────────────────────────────────────── */
.tty-caret {
  display: inline-block;
  width: 0.55em;
  height: 1em;
  vertical-align: -0.13em;
  background: var(--yellow);
  animation: tty-blink var(--blink-rate) var(--ease-step-2) infinite;
}
.tty-caret--bar { width: 2px; }

/* ── Foldout, as a native <details> ─────────────────────────────────────── */
.tty-foldout { border-top: var(--border-w) solid var(--border-faint); }
.tty-foldout__summary {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: var(--tap-min);
  padding: 0 2px;
  font: var(--text-xs)/1 var(--font-display);
  letter-spacing: var(--tracking-label);
  text-transform: uppercase;
  color: var(--text-muted);
  -webkit-font-smoothing: none;
  font-smooth: never;
  cursor: pointer;
  list-style: none;
}
.tty-foldout__summary::-webkit-details-marker { display: none; }
.tty-foldout__summary::before { content: "▸"; font-family: var(--font-glyph); }
.tty-foldout[open] > .tty-foldout__summary { color: var(--yellow); }
.tty-foldout[open] > .tty-foldout__summary::before { content: "▾"; }
.tty-foldout__hint { color: var(--text-faint); }
.tty-foldout__body {
  padding: 4px 0 16px;
  animation: tty-wipe-up var(--dur-fast) var(--ease-step-4);
}

/* ── Prose wrapper ──────────────────────────────────────────────────────── */
.tty-prose {
  max-width: var(--measure-prose);
  font-family: var(--font-body);
  font-size: var(--text-lg);
  line-height: var(--leading-body);
  color: var(--text-secondary);
  text-wrap: pretty;
}
.tty-prose--wide { max-width: var(--measure-wide); }
.tty-prose--md { font-size: var(--text-md); }

/* ── Figures break out of the reading measure ───────────────────────────────
   A plot is not body copy. `--measure-prose` is 68ch, which is about 694px at
   `--text-lg`. Three posts carry 15 figures, and twelve of them are multi-panel
   `kc-*` plots up to 2101x479px: inside 694px each panel is about 170px wide and
   the axis labels, firm names and legends stop being readable.

   So a figure grows past the text column: to `--measure-wide` (92ch, about
   938px) from 1280px up, and to the page column (`--page-max` less the two
   gutters, 1184px) from 1440px up, where there is room for the whole plot.

   Three selectors, and no post is edited:
     1. `.tty-figure` — the class a new post may use.
     2. `div[style*="justify-content: center"]` — the raw markup the 15 existing
        figures already carry.
     3. `p:has(> img:only-child)` — what markdown-it emits for `![alt](src)`,
        which is the only image syntax the Markdown author needs.

   `position: relative` plus a negative `left` does the offset, not a margin.
   The post column is centred in the page (`.tty-post` in Task 8), so pulling the
   box left by half the extra width centres the figure in the page, and Task 17's
   `margin: var(--sp-8) 0 0` on the same figures keeps working — the two rules set
   different properties and cannot fight. The caption below stays at the reading
   measure, because a centred caption 1184px wide reads worse, not better. */
@media (min-width: 1280px) {
  .tty-prose > .tty-figure,
  .tty-prose > div[style*="justify-content: center"],
  .tty-prose > p:has(> img:only-child) {
    position: relative;
    left: calc((var(--measure-prose) - var(--measure-wide)) / 2);
    width: var(--measure-wide);
    /* A guard, so a wider measure token can never overflow the page column. */
    max-width: calc(var(--page-max) - 2 * var(--gutter));
  }
}
@media (min-width: 1440px) {
  .tty-prose > .tty-figure,
  .tty-prose > div[style*="justify-content: center"],
  .tty-prose > p:has(> img:only-child) {
    left: calc((var(--measure-prose) - var(--page-max) + 2 * var(--gutter)) / 2);
    width: calc(var(--page-max) - 2 * var(--gutter));
  }
}
```

- [ ] **Step 4: Write the content macros**

Create `src/_includes/tty/content.njk`:

```njk
{#
  TTY content macros. Import as:  {% import "tty/content.njk" as ttyc %}

  postrow() needs the `postDate` and `readingTime` filters. `readingTime` is
  registered in .eleventy.js by Task 7, so do not render this file before that
  task lands.
#}

{% macro postrow(post, index, archived=false) %}
<a class="tty-postrow" href="{{ post.url }}">
  <div class="tty-postrow__index">{{ index }}</div>
  <div class="tty-postrow__body">
    <h3 class="tty-postrow__title">{{ post.data.title }}</h3>
    {% if post.data.description %}<p class="tty-postrow__excerpt">{{ post.data.description }}</p>{% endif %}
    {% if post.data.tags and post.data.tags.length %}
    <div class="tty-postrow__tags">
      {% for t in post.data.tags %}<span>#{{ t }}</span>{% endfor %}
    </div>
    {% endif %}
  </div>
  <div class="tty-postrow__meta">
    <time datetime="{{ post.date.toISOString() }}">{{ post.date | postDate }}</time>
    <span>{{ post | readingTime }}</span>
    {% if archived %}<span class="tty-badge tty-badge--outline tty-badge--warn">archived</span>{% endif %}
  </div>
</a>
{%- endmacro %}

{#
  terminal() takes its transcript through caller():

    {% call ttyc.terminal("~/posts") %}
      <div class="tty-term__line"><span class="tty-term__prompt">$</span> <span>whoami</span></div>
    {% endcall %}
#}
{% macro terminal(name, chrome="tab") %}
<div class="tty-term">
  <div class="tty-term__bar">
    {% if chrome == "dots" %}
    <span class="tty-term__dots" aria-hidden="true">
      <span class="tty-term__dot tty-term__dot--r"></span>
      <span class="tty-term__dot tty-term__dot--y"></span>
      <span class="tty-term__dot tty-term__dot--g"></span>
    </span>
    <span class="tty-term__name tty-term__name--center">{{ name }}</span>
    {% else %}
    <span class="tty-term__tab">{{ name }}</span>
    <span class="tty-term__name"></span>
    {% endif %}
  </div>
  <div class="tty-term__body">{{ caller() }}</div>
</div>
{%- endmacro %}

{#
  foldout() wraps a native <details>, so the compact filter rail needs no script:

    {% call ttyc.foldout("filter", "9 tags") %}
      …rail body…
    {% endcall %}
#}
{% macro foldout(label, hint="") %}
<details class="tty-foldout">
  <summary class="tty-foldout__summary">
    <span>{{ label }}</span>
    {% if hint %}<span class="tty-foldout__hint">{{ hint }}</span>{% endif %}
  </summary>
  <div class="tty-foldout__body">{{ caller() }}</div>
</details>
{%- endmacro %}
```

- [ ] **Step 5: Add the import**

In `src/styles/tty.css`, add one line after the `tty/core.css` import:

```css
@import "tty/content.css";
```

- [ ] **Step 6: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 7: Commit**

```bash
git add src/styles/tty/content.css src/styles/tty.css src/_includes/tty/content.njk scripts/check-build.sh
git commit -m "feat(design): port the TTY content components

PostCard becomes one anchor per row, TerminalWindow keeps its scanline texture
and hard shadow, Foldout drops its React state for a native <details>, and the
caret and prose wrapper arrive. No template consumes the macros yet."
```

---
### Task 5: Replace the page shell and drop Pico CSS

This is the task that changes how the site looks. Pico CSS leaves, `style.css` and
`blog.css` stop being linked, the `Site.jsx` shell arrives: sticky nav with the
`ELLIANCARLOS_` wordmark and a tab strip, a page-max main column, and the terminal-flavoured
footer. Body copy across the site becomes JetBrains Mono on `#0A0A09`.

After this task the pages render in the new system but their *content* markup is still the
old Pico markup. Post bodies, post rows, and tag pills look plain. Tasks 6 to 15 fix each
screen. That is expected, and the build stays green throughout.

**Files:**
- Create: `src/styles/tty/layout.css`
- Create: `src/_includes/nav.njk`
- Modify: `src/_includes/layouts/layout.njk` (full rewrite)
- Modify: `src/_includes/footer.njk` (full rewrite)
- Create: `src/scripts/tty-search.js` (stub; Task 9 overwrites it)
- Modify: `src/_data/i18n/en.json` (full rewrite — the whole migration's strings)
- Modify: `src/styles/tty.css`
- Modify: `scripts/check-build.sh`
- Delete: `src/_includes/header.njk`
- Delete: `src/_includes/pageHeader.njk`
- Delete: `src/_includes/languageDropdown.njk`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `.tty-tabs`, `.tty-tabs__tab`, `.tty-spacer`, `.tty-rule`, `tty.keyhint`
  from Task 3. `.tty-caret`, `.tty-term__prompt` from Task 4. `seo.social.*` from
  `src/_data/seo.js`.
- Produces the CSS classes: `.tty-shell`, `.tty-nav` (`.tty-nav__mark`,
  `.tty-nav__caret`, `.tty-nav__search`), `.tty-main`, `.tty-foot`
  (`.tty-foot__inner`, `.tty-foot__row`, `--quiet`, `.tty-foot__cmd`,
  `.tty-foot__links`, `.tty-foot__meta`, `.tty-foot__mark`), `.tty-screen`,
  `.tty-section`, `.tty-eyebrow`, `.tty-h1`, `.tty-h1--hero`, `.tty-h2`,
  `.tty-split`, `.tty-split--rail`, `.tty-split--rail-wide`, `.tty-rail`,
  `.tty-linklist` (`.tty-linklist__row`, `.tty-linklist__key`),
  `.tty-when-desktop`, `.tty-when-compact`.
- Produces `src/_includes/nav.njk`, included by `layout.njk`. It reads `page.url` to mark
  the active tab, `i18n[locale].nav.*` for the labels, and `collections.all` to drop a tab
  whose page the build does not write. Task 13 writes `/preprints/`, so the strip shows
  three tabs until then and no task ships a nav link that 404s.
- Produces `src/scripts/tty-search.js` as a stub. `layout.njk` loads that script on every
  page, so the file must exist from this task. Task 9 overwrites it with the real overlay
  controller. The stub reveals the nav search control only when an overlay exists to open,
  so no task ships a visible control that does nothing.
- Produces the **complete** `src/_data/i18n/en.json` for the whole migration — the
  `language`, `nav`, `search`, `blog`, `post`, `preprints`, `contact`, `error`, `footer`
  and `seo` objects, every key at its final value. Tasks 8, 10, 13 and 15 read keys from
  this file and must not edit it. That is what makes those four tasks independent of each
  other.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "page shell"
have "styles/tty/layout.css"
grep_in "styles/tty/layout.css" "overflow-x: clip" "body is not turned into a scroll container"
grep_in "styles/tty/layout.css" "html:has(body.tty-search-open)" "the scroll lock lands on the element the viewport scrolls"
have "scripts/tty-search.js"
grep_in "styles/tty.css" '@import "tty/layout.css"' "the entry stylesheet imports layout.css"
grep_not "index.html" "picocss" "Pico CSS is gone from the homepage"
grep_not "posts/index.html" "picocss" "Pico CSS is gone from the blog index"
grep_not "404.html" "picocss" "Pico CSS is gone from the 404 page"
grep_not "index.html" "/styles/style.css" "the old stylesheet is unlinked"
grep_not "posts/index.html" "/styles/blog.css" "the old blog stylesheet is unlinked"
grep_in "index.html" '<link rel="stylesheet" href="/styles/tty.css">' "the homepage links tty.css"
grep_in "index.html" 'class="tty-nav__mark"' "the wordmark is present"
count_at_least "index.html" 'class="tty-tabs__tab"' 3 "the three live nav tabs render"
grep_not "index.html" 'href="/preprints/"' "the nav ships no tab for a page the build does not write"
grep_in "index.html" 'data-tty-search-open hidden' "the search control stays hidden until a script can open it"
grep_in "index.html" 'class="tty-foot"' "the new footer is present"
grep_in "posts/index.html" 'aria-current="page"' "the active tab is marked on /posts/"
grep_in "index.html" 'content="#0A0A09"' "the theme colour is the root surface"
grep_not "index.html" "mobile-menu-toggle" "the old hamburger is gone"
grep_not "index.html" "page-header-content" "the old page header is gone"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `file styles/tty/layout.css is missing`, `Pico CSS is gone from the
homepage`, and seventeen more.

- [ ] **Step 3: Write the layout CSS**

Create `src/styles/tty/layout.css`:

```css
/* TTY page shell — ported from ui_kits/blog/Site.jsx plus the screen grids the
   Home, Archive and About screens share. The search overlay lives here too,
   because it is shell furniture, not a component. */

html { height: 100%; }

/* tokens/breakpoints.css ends with `html, body { overflow-x: hidden; }`. That line
   is why the page never scrolls sideways, and it must keep doing that job: the
   rule stays on <html>, where it propagates to the viewport.
   On <body> it does something else as well. Per CSS Overflow 3, a `visible` value
   beside a value that is neither `visible` nor `clip` computes to `auto`, so
   body's unset `overflow-y` becomes `auto` and <body> becomes a scroll container.
   A sticky box is offset against its nearest scroll container, and body's
   scrollport never scrolls, because body's height is auto. Every
   `position: sticky` under <body> therefore stops working: `.tty-nav` and
   `.tty-rail--sticky` below, and with them the `scroll-margin-top` offsets in
   Task 6 and Task 11, which exist only to clear a sticky nav.
   `clip` is the one value that pairs with `visible` and is left alone, so it
   clips the sideways overflow without creating a scrollport. The token files are
   vendored verbatim and must not be edited, so the override lands here;
   layout.css is imported after tokens/breakpoints.css and wins on equal
   specificity. An engine that does not know `overflow-x: clip` drops this line
   and keeps today's behaviour. */
body { overflow-x: clip; }

.tty-shell {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: var(--surface-root);
}

/* ── Sticky nav ─────────────────────────────────────────────────────────── */
.tty-nav {
  position: sticky;
  top: 0;
  z-index: 30;
  display: flex;
  align-items: center;
  gap: 16px;
  height: 52px;
  padding: 0 var(--gutter);
  background: var(--surface-root);
  border-bottom: var(--border-w) solid var(--border-faint);
}
.tty-nav__mark {
  flex: none;
  display: inline-flex;
  align-items: center;
  gap: 1px;
  font-family: var(--font-display);
  font-size: 18px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--yellow);
  -webkit-font-smoothing: none;
  font-smooth: never;
  text-decoration: none;
  border: 0;
}
.tty-nav__mark:hover { color: var(--yellow-bright); }
.tty-nav__caret { background: var(--text-primary); }
.tty-nav > .tty-tabs { border-bottom: 0; align-self: stretch; }
.tty-nav__search {
  flex: none;
  min-height: var(--tap-min);
  padding: 0 4px;
  background: transparent;
  border: 0;
  cursor: pointer;
}

/* The wordmark alone is 150px at 18px Silkscreen; on a small phone the tab
   strip needs the rest of the row, so the mark steps down instead of wrapping. */
@media (max-width: 430px) {
  .tty-nav { gap: 10px; }
  .tty-nav__mark { font-size: var(--display-xs); letter-spacing: 0.08em; }
}

/* ── Main column ────────────────────────────────────────────────────────── */
.tty-main {
  flex: 1;
  width: 100%;
  max-width: var(--page-max);
  margin: 0 auto;
  padding: var(--sp-section) var(--gutter) calc(var(--sp-section) + 8px);
}

/* A screen is a stack of sections at the section rhythm. */
.tty-screen { display: flex; flex-direction: column; gap: var(--sp-section); }
.tty-section { display: flex; flex-direction: column; gap: var(--sp-block); }

/* ── Display type ───────────────────────────────────────────────────────── */
.tty-eyebrow {
  font-size: var(--text-xs);
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--text-faint);
}
.tty-h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: var(--display-md);
  line-height: var(--leading-tight);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--text-primary);
  -webkit-font-smoothing: none;
  font-smooth: never;
}
.tty-h1--hero {
  font-size: var(--display-xl);
  line-height: 1.05;
  letter-spacing: 0.04em;
}
.tty-h1--hero .tty-accent { color: var(--yellow); }
.tty-h2 {
  margin: 0;
  font-family: var(--font-display);
  font-size: var(--display-md);
  line-height: var(--leading-tight);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--yellow);
  -webkit-font-smoothing: none;
  font-smooth: never;
}

/* ── Screen grids ───────────────────────────────────────────────────────── */
.tty-split { display: grid; grid-template-columns: minmax(0, 1fr); gap: 28px; }
.tty-split--rail { align-items: start; }
.tty-split--rail-wide { align-items: start; }

@media (min-width: 1280px) {
  .tty-split { grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr); gap: 48px; align-items: center; }
  .tty-split--rail { grid-template-columns: minmax(0, 1fr) 220px; gap: 48px; align-items: start; }
  .tty-split--rail-wide { grid-template-columns: minmax(0, 1fr) 280px; gap: 48px; align-items: start; }
}

.tty-rail { display: flex; flex-direction: column; gap: 20px; }
@media (min-width: 1280px) {
  .tty-rail--sticky { position: sticky; top: calc(52px + var(--sp-6)); }
}

/* Two layouts, not five: the rail is an aside on desktop and a <details> under
   1280px. Both markups render; CSS picks one. The source stays DRY because both
   call the same macro. */
.tty-when-desktop { display: none; }
.tty-when-compact { display: block; }
@media (min-width: 1280px) {
  .tty-when-desktop { display: block; }
  .tty-when-compact { display: none; }
}

/* ── Key/value link list ("Elsewhere") ──────────────────────────────────── */
.tty-linklist { display: flex; flex-direction: column; gap: var(--sp-2); font-size: var(--text-sm); }
.tty-linklist__row { display: flex; align-items: center; gap: 16px; min-height: var(--tap-min); }
.tty-linklist__key {
  flex: none;
  width: 72px;
  font-size: var(--text-xs);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--text-faint);
}

/* ── Footer ─────────────────────────────────────────────────────────────── */
.tty-foot {
  border-top: var(--border-w) solid var(--border-faint);
  background: var(--surface-panel);
}
.tty-foot__inner {
  max-width: var(--page-max);
  margin: 0 auto;
  padding: 22px var(--gutter);
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.tty-foot__row {
  display: flex;
  align-items: center;
  gap: 14px;
  flex-wrap: wrap;
  font-size: var(--text-xs);
  color: var(--text-faint);
}
.tty-foot__row--quiet { color: var(--text-faint); opacity: 0.8; }
.tty-foot__cmd { font-family: var(--font-code); }
.tty-foot__links { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.tty-foot__meta { display: flex; align-items: center; gap: 6px; }
.tty-foot__mark {
  font-family: var(--font-display);
  font-size: 12px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--text-muted);
  -webkit-font-smoothing: none;
  font-smooth: never;
}

/* ── Search overlay ─────────────────────────────────────────────────────── */
.tty-search[hidden] { display: none; }
.tty-search {
  position: fixed;
  inset: 0;
  z-index: 80;
  display: flex;
  justify-content: center;
  padding: clamp(16px, 12vh, 120px) var(--gutter) 0;
}
.tty-search__scrim { position: absolute; inset: 0; background: var(--surface-scrim); }
.tty-search__panel {
  position: relative;
  width: 620px;
  max-width: 100%;
  height: fit-content;
  max-height: 80vh;
  overflow: auto;
  background: var(--surface-panel);
  border: var(--border-w) solid var(--yellow);
  box-shadow: var(--shadow-hard);
  animation: tty-wipe-up var(--dur-base) var(--ease-step-8);
}
.tty-search__field { padding: 10px; border-bottom: var(--border-w) solid var(--border-faint); }
.tty-search__foot {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 8px 12px;
  border-top: var(--border-w) solid var(--border-faint);
  font-size: var(--text-xs);
  color: var(--text-faint);
}
.tty-search__empty { padding: 14px; font-size: var(--text-sm); color: var(--text-faint); }

/* While the overlay is open the page behind it must not scroll.
   The lock has to land on <html>, not on <body>. tokens/breakpoints.css gives
   <html> a non-visible `overflow-x`, so the viewport takes its overflow from
   <html>; body's overflow no longer propagates, and `overflow: hidden` on a body
   whose height is auto clips nothing at all.
   `hidden` is what locks it, and `clip` must not be used here: `hidden` keeps the
   scrollport, so the scroll offset survives and the page is exactly where the
   reader left it when the overlay closes, while `clip` removes the scrollport and
   the page jumps back to the top.
   `:has()` keeps the DOM contract the script declares — one class, on <body>.
   `html.tty-search-open` is listed as well, so the lock still holds if the script
   sets the class on <html> too.
   `scrollbar-gutter: stable` reserves the scrollbar space at all times, so the
   page does not shift sideways the moment the lock removes the scrollbar. */
html { scrollbar-gutter: stable; }
html:has(body.tty-search-open),
html.tty-search-open { overflow: hidden; }
body.tty-search-open { overflow: hidden; }
```

- [ ] **Step 4: Write the nav**

Create `src/_includes/nav.njk`:

```njk
{% import "tty/core.njk" as tty %}
{#
  The tab strip replaces the old hamburger menu. It scrolls sideways under
  1280px instead of collapsing, which is the design system's compact idiom and
  needs no JavaScript.

  `resume` and `academic cv` are not tabs — they are external documents, and they
  live in the footer and in the Elsewhere list on the homepage.

  A tab renders only when the build writes its page. `/preprints/` arrives in
  Task 13, so until then the strip shows three tabs and no task ships a nav link
  that 404s. The gate is one string: `collections.all | join(" ", "url")` is every
  URL the build writes, space delimited, and `indexOf` looks one up. Nunjucks'
  `join` filter takes an attribute name as its third argument.
#}
{% set liveUrls = " " + (collections.all | join(" ", "url")) + " " %}
{% set navItems = [
  { url: "/", label: i18n[locale].nav.about },
  { url: "/posts/", label: i18n[locale].nav.posts },
  { url: "/posts/archive/", label: i18n[locale].blog.archive, count: collections.posts_en.length },
  { url: "/preprints/", label: i18n[locale].nav.preprints },
  { url: "/contact/", label: i18n[locale].nav.contact }
] %}
<header class="tty-nav">
  <a class="tty-nav__mark" href="/">elliancarlos<span class="tty-caret tty-nav__caret" aria-hidden="true"></span></a>
  <nav class="tty-tabs" aria-label="Main">
    {%- for item in navItems -%}
      {%- if liveUrls.indexOf(" " + item.url + " ") >= 0 -%}
      {%- set on = (page.url == item.url) or (item.url != "/" and page.url.indexOf(item.url) == 0) -%}
      <a class="tty-tabs__tab" href="{{ item.url }}"{% if on %} aria-current="page"{% endif %}>{{ item.label }}{% if item.count %}<span class="tty-tabs__count">({{ item.count }})</span>{% endif %}</a>
      {%- endif -%}
    {%- endfor -%}
  </nav>
  <span class="tty-spacer"></span>
  {#
    The search control ships `hidden`. /scripts/tty-search.js reveals it, and only
    when an overlay exists to open, so no task ships a visible control that does
    nothing and no page advertises a `/` binding that is not installed. With
    JavaScript off the control stays hidden, and every post stays reachable from
    /posts/, sitemap.xml and feed.xml.
  #}
  <button class="tty-nav__search" type="button" data-tty-search-open hidden
          aria-label="{{ i18n[locale].search.open }}" aria-controls="tty-search" aria-expanded="false">
    {{ tty.keyhint(["/"], "search") }}
  </button>
</header>
```

- [ ] **Step 5: Rewrite the footer**

Replace the whole of `src/_includes/footer.njk` with:

```njk
<footer class="tty-foot">
  <div class="tty-foot__inner">
    <div class="tty-foot__row">
      <span class="tty-foot__cmd"><span class="tty-term__prompt">$</span> eleventy --input src --output dist</span>
      <span class="tty-spacer"></span>
      <span class="tty-foot__links">
        <span class="tty-foot__mark">{{ i18n[locale].footer.feeds }}</span>
        <a href="/feed.xml">feed.xml</a>
        <span aria-hidden="true">·</span>
        <a href="/llms.txt">llms.txt</a>
        <span aria-hidden="true">·</span>
        <a href="/sitemap.xml">sitemap.xml</a>
      </span>
    </div>
    <hr class="tty-rule">
    <div class="tty-foot__row">
      <span class="tty-foot__links">
        <span class="tty-foot__mark">{{ i18n[locale].footer.elsewhere }}</span>
        <a href="/Ellian_Carlos_Resume.pdf">{{ i18n[locale].nav.resume }}</a>
        <span aria-hidden="true">·</span>
        <a href="{{ seo.social.lattes }}" target="_blank" rel="noreferrer noopener">{{ i18n[locale].nav.academicCv }}</a>
        <span aria-hidden="true">·</span>
        <a href="{{ seo.social.github }}" target="_blank" rel="noreferrer noopener">github</a>
        <span aria-hidden="true">·</span>
        <a href="{{ seo.social.linkedin }}" target="_blank" rel="noreferrer noopener">linkedin</a>
        <span aria-hidden="true">·</span>
        <a href="{{ seo.social.mastodon }}" target="_blank" rel="me noreferrer noopener">mastodon</a>
        <span aria-hidden="true">·</span>
        <a href="{{ seo.social.orcid }}" target="_blank" rel="noreferrer noopener">orcid</a>
      </span>
      <span class="tty-spacer"></span>
      <span class="tty-foot__meta">
        {{ i18n[locale].footer.copyleft }}
        <a href="https://www.github.com/elliancarlos/elliancarlos.github.io">{{ i18n[locale].footer.source }}</a>
      </span>
    </div>
    <div class="tty-foot__row tty-foot__row--quiet">
      <span class="tty-foot__mark">elliancarlos</span>
      <span aria-hidden="true">·</span>
      <span>{{ i18n[locale].footer.inspired }} <a href="https://m7.rs/" target="_blank" rel="noreferrer noopener">misterio's page</a></span>
    </div>
  </div>
</footer>
```

- [ ] **Step 6: Rewrite the base layout**

Replace the whole of `src/_includes/layouts/layout.njk` with:

```njk
---
type: index
---
<!DOCTYPE html>
<html lang="{{ locale or 'en' }}">

<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="color-scheme" content="dark">
  <meta name="theme-color" content="#0A0A09">

  <!-- SEO Meta Tags -->
  {% set pageTitle = seoTitle or title or i18n[locale].seo.defaultTitle %}
  {% if pageTitle != seo.siteName %}
    <title>{{ pageTitle }} | {{ seo.siteName }}</title>
  {% else %}
    <title>{{ seo.siteName }}</title>
  {% endif %}

  <meta name="description" content="{{ description or i18n[locale].seo.defaultDescription }}">
  <meta name="author" content="{{ seo.author.name }}">

  <!-- Canonical URL -->
  <link rel="canonical" href="{{ seo.baseUrl }}{{ page.url }}">

  <!-- Open Graph Tags -->
  <meta property="og:title" content="{{ pageTitle }}">
  <meta property="og:description" content="{{ description or i18n[locale].seo.defaultDescription }}">
  <meta property="og:type" content="{{ ogType or 'website' }}">
  <meta property="og:url" content="{{ seo.baseUrl }}{{ page.url }}">
  <meta property="og:image" content="{{ ogImage or seo.defaultImage }}">
  <meta property="og:locale" content="{{ locale or 'en' }}">
  <meta property="og:site_name" content="{{ seo.siteName }}">

  <!-- Twitter Card Tags -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{{ pageTitle }}">
  <meta name="twitter:description" content="{{ description or i18n[locale].seo.defaultDescription }}">
  <meta name="twitter:image" content="{{ ogImage or seo.defaultImage }}">

  <!-- hreflang tags for SEO -->
  {% if i18nEnabled %}
  {% for lang in languages %}
    <link rel="alternate" hreflang="{{ lang }}" href="{{ seo.baseUrl }}{{ page.url | switchLanguage(lang) }}" />
  {% endfor %}
  <link rel="alternate" hreflang="x-default" href="{{ seo.baseUrl }}{{ page.url | switchLanguage('en') }}" />
  {% endif %}

  <!-- Feed -->
  <link rel="alternate" type="application/atom+xml" title="{{ seo.siteName }}" href="/feed.xml">

  <!-- Favicon -->
  <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
  <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
  <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">

  <!-- Both webfonts and the maths stylesheet come from jsdelivr. -->
  <link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>

  <!-- Stylesheets: tty.css is the whole design system. -->
  <link rel="stylesheet" href="/styles/tty.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.47/dist/katex.min.css" crossorigin="anonymous">

  <!-- Structured Data -->
  {% include "structuredData.njk" %}
</head>
<body class="tty-shell">
    {% include "nav.njk" %}
    <main class="tty-main">
        {{ content | safe }}
    </main>
    {% include "footer.njk" %}
    {% include "searchOverlay.njk" %}
    {% if i18nEnabled %}{% include "languageRedirect.njk" %}{% endif %}

    <script defer src="/scripts/tty-search.js"></script>

    <!-- Google tag (gtag.js) -->
    <script async src="https://www.googletagmanager.com/gtag/js?id=G-2GHK298WZ2"></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());

      gtag('config', 'G-2GHK298WZ2');
    </script>
</body>
</html>
```

Two notes on this rewrite:

- `searchOverlay.njk` and `tty-search.js` arrive in **Task 9**, not Task 10. Until then
  this task ships a stub of each, both in Step 8: an empty
  `src/_includes/searchOverlay.njk` so the include resolves, and a real
  `src/scripts/tty-search.js` so the `<script>` tag above resolves. Task 9 writes both
  files for real, which overwrites both stubs, so Task 9 needs no edit to this layout and
  no new entry in its file list. Moving the `<script>` tag into Task 9 instead would need
  both, and would leave Task 5's own markup describing a script that is not loaded.
- `relative_path` is gone from the frontmatter. Nothing reads it —
  `grep -rn relative_path src/ .eleventy.js` finds only the five places that *set* it.
  Task 16 removes the remaining four.

- [ ] **Step 7: Land the complete i18n file**

This task writes `src/_data/i18n/en.json` once, for the whole migration. Every key any
later task reads is here, at its final value. Tasks 8, 10, 13 and 15 read this file and
must not edit it, and Task 11 no longer waits on Task 10 for the seven `blog.*` keys its
template reads. One edit, one place, no ordering constraint.

Replace the whole of `src/_data/i18n/en.json` with:

```json
{
  "language": {
    "name": "English",
    "code": "en"
  },
  "nav": {
    "about": "about",
    "posts": "posts",
    "preprints": "preprints",
    "contact": "contact",
    "resume": "resume",
    "academicCv": "academic cv"
  },
  "search": {
    "open": "Search posts",
    "placeholder": "search posts, tags, words…",
    "results": "results",
    "result": "result",
    "noResults": "no results",
    "openHint": "open",
    "closeHint": "close"
  },
  "blog": {
    "eyebrow": "Notes on kernels, open source, and the tools I keep",
    "heroLine1": "Notes from",
    "heroLine2": "the kernel",
    "heroLine3": "and the tools",
    "lead": "Long-form notes on the Linux kernel, on how open source work concentrates in a few hands, and on the tools I keep on disk. Most of it started as a note to myself.",
    "readArchive": "Read the archive",
    "readPosts": "Read the posts",
    "latestPost": "Latest post",
    "recent": "recent",
    "feeds": "feeds",
    "feedsHint": "3 endpoints",
    "searchHint": "press / anywhere",
    "allPosts": "all posts",
    "archive": "archive",
    "postsTagged": "posts tagged",
    "noPostsWithTag": "No posts carry this tag.",
    "tagged": "tagged",
    "byYear": "by year",
    "tags": "tags",
    "filter": "filter",
    "sortNewest": "newest first",
    "sortOldest": "oldest first",
    "post": "post",
    "count": "posts"
  },
  "post": {
    "translationWarning": {
      "title": "automatic translation",
      "message": "A language model translated this post from English. It may contain inaccuracies, or nuances lost in translation."
    },
    "archived": {
      "title": "archived",
      "message": "This post is no longer listed on the posts page. A newer post supersedes it. The text stays here unchanged."
    },
    "publishedOn": "published",
    "updatedOn": "updated",
    "backToPosts": "posts",
    "next": "next"
  },
  "preprints": {
    "title": "preprints",
    "description": "Papers I have written or co-written. Each row opens the PDF in a new tab.",
    "paper": "paper",
    "papers": "papers",
    "openHint": "each row opens a pdf"
  },
  "contact": {
    "title": "contact",
    "email": "email",
    "social": "social"
  },
  "error": {
    "title": "page not found",
    "message": "That path does not resolve. The post may have moved, or the link may be wrong.",
    "home": "Go home"
  },
  "footer": {
    "feeds": "feeds",
    "elsewhere": "elsewhere",
    "copyleft": "copyleft",
    "source": "source",
    "inspired": "inspired by"
  },
  "seo": {
    "defaultTitle": "Ellian Carlos",
    "defaultDescription": "Software engineer, problem solver, and student passionate about languages, mathematics, and building scalable systems.",
    "home": {
      "title": "Ellian Carlos",
      "description": "Brazilian software engineer at Amazon, math and information systems student, passionate about languages and problem solving."
    },
    "blog": {
      "title": "Blog",
      "description": "Thoughts on software engineering, tools, languages, and technology."
    },
    "contact": {
      "title": "Contact",
      "description": "Get in touch with Ellian Carlos via email or social media."
    },
    "404": {
      "title": "Page Not Found",
      "description": "The page you're looking for doesn't exist."
    }
  }
}
```

Six notes on the file:

- Dropped: `nav.aboutme`, `nav.blog`, `footer.social`, `footer.sourceCode`, the whole
  `home` object, `blog.searchPlaceholder` and `blog.noResults`. The templates that read
  the first four are deleted or rewritten in this task, the search strings move into
  `search`, and `home.*` has no reader at all — `grep -rn "i18n\[locale\].home" src/`
  finds none.
- Kept for one reason only: `blog.tagged`, `post.publishedOn` and `post.updatedOn`,
  because the old `layouts/post.njk` still reads them until Task 8 rewrites it, and
  `contact.*` until Task 15 does the same. Task 8 must not add `tagged` to its `post`
  object, and nothing after Task 15 needs `contact.social`.
- Counted labels carry a singular and a plural: `blog.post`/`blog.count` and
  `preprints.paper`/`preprints.papers`. The templates pick one on the count, so
  `/preprints/` does not read "1 papers" and the nine single-post tag pages do not read
  "1 posts".
- `blog.feedsHint` is `3 endpoints`. The feeds panel lists three URLs; its fourth row is
  the `/` key hint, which is not an endpoint.
- `blog.readArchive` labels the button that goes to `/posts/archive/`. `blog.readPosts`
  labels the homepage button that goes to `/posts/`. One label must not serve two targets.
- Leave `pt.json`, `es.json` and `ja.json` untouched — they are unused while
  `I18N_ENABLED` is `false`. Flag the gap to the owner: if i18n is ever re-enabled, those
  three files need the same keys or the nav labels render empty.

- [ ] **Step 8: Add the import, ship the two stubs, delete the dead includes**

In `src/styles/tty.css`, add after the `tty/content.css` import:

```css
@import "tty/layout.css";
```

`layout.njk` includes `searchOverlay.njk` and loads `/scripts/tty-search.js` on every page.
Task 9 writes both files for real. This task ships a stub of each, so no page in Tasks 5 to
8 asks for a file that is not there.

The overlay stub is empty:

```bash
printf '' > src/_includes/searchOverlay.njk
```

The script stub is real code. Create `src/scripts/tty-search.js`:

```js
/* Stub. Task 9 overwrites this file with the overlay controller. layout.njk
   loads this script on every page, so the file must exist from this task, or
   every page requests a 404.
   The one job it has is to keep the nav honest. The search control ships with
   `hidden`, and this stub reveals it only when there is an overlay to open.
   searchOverlay.njk is still empty, so nothing is revealed yet and the reader
   never sees a control that does nothing. */
(function () {
  if (!document.getElementById("tty-search")) return;
  var openers = document.querySelectorAll("[data-tty-search-open]");
  for (var i = 0; i < openers.length; i += 1) {
    openers[i].removeAttribute("hidden");
  }
})();
```

Task 9 must keep that `removeAttribute("hidden")` line in the real script, or the nav
control stays hidden for good. The `/` key binding works either way.

Then remove the three includes the nav replaces:

```bash
git rm src/_includes/header.njk src/_includes/pageHeader.njk src/_includes/languageDropdown.njk
```

`languageDropdown.njk` is dead already — no template includes it. Confirm with
`grep -rn languageDropdown src/` before you delete, and expect no match.

- [ ] **Step 9: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 10: Look at it**

Run: `bun run start` and open `http://localhost:8080/`.
Expect: black page, yellow `ELLIANCARLOS_` wordmark with a blinking caret, three tabs —
`about`, `posts`, `contact` — with `about` active, JetBrains Mono body copy, and the
three-row footer. The biography text is still unstyled Pico markup — Task 14 fixes it.

Three things must be checked by hand, because `check-build.sh` only reads text:

1. Scroll to the foot of the page. The nav must stay pinned at the top the whole way. If
   it scrolls away, the `body { overflow-x: clip; }` override from Step 3 is missing.
2. There is no `/ search` key hint yet, and that is correct. The control is in the markup
   with `hidden`, and the stub script leaves it hidden because no overlay exists. Task 9
   ships the overlay and the hint appears.
3. There is no `preprints` tab yet, and that is correct too. Task 13 writes that page, and
   the nav renders a tab only for a page the build writes. Open the browser console and
   confirm it is clean: no 404 for `/scripts/tty-search.js`.

Stop the server before you run the check again.

- [ ] **Step 11: Commit**

```bash
git add -A src/styles src/scripts src/_includes src/_data/i18n/en.json scripts/check-build.sh
git commit -m "feat(design): replace the page shell and remove Pico CSS

The sticky nav, main column and footer come from the design system Site
screen. The wordmark is ELLIANCARLOS_ in Silkscreen yellow with a blinking
caret. The hamburger menu, the shell-prompt page header and the dead language
dropdown are gone; a horizontally scrolling tab strip replaces them and needs
no script. Pico CSS, style.css, blog.css and Montserrat are unlinked.

Page content markup is still the old markup and looks plain. The following
commits restyle each screen."
```

---
### Task 6: Style long-form prose and code

Task 5 unlinked the Prism theme, so code blocks currently render unstyled. This task
supplies the replacement and the whole long-form reading treatment: headings, lists,
quotes, tables, figures, inline code, and maths.

Not every fence is a Prism block. Four fences carry no info string — three in
`how-linux-kernel-submissions-work.md` (lines 54, 304 and 355) and one in
`howbuilding-custom-arm-linux-kernel-with-kw.md` (line 324). The syntax highlight plugin
gives those no `language-*` class, so they build as a bare `<pre><code>` and no
`pre[class*="language-"]` rule can reach them. Step 3 styles that case on its own. One of
those blocks is 242 lines long with a 99-character line, and another holds a 120-character
`git send-email` command, so the missing scroller is the part that matters:
`tokens/breakpoints.css` ends with `html, body { overflow-x: hidden }`, which clips a block
that has no scroller of its own.

It also takes the Prism toolbar CSS off the CDN. `.eleventy.js` injects that link
*before* `</body>`, so it lands after our head stylesheet in document order and wins every
tie. Owning those twenty lines removes one request and the specificity fight at once.

**Documented deviation.** `CodeBlock.jsx` draws line numbers, a filename slot and a
yellow-wash highlight for selected lines. Prism's output has none of those, so this task
keeps the 26px header strip and the language label and drops the other three.

**Files:**
- Create: `src/styles/tty/prose.css`
- Create: `src/styles/tty/prism-tty.css`
- Modify: `src/styles/tty.css`
- Modify: `.eleventy.js:135-148` (the `PRISM_PLUGIN_BLOCK` constant)
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `.tty-prose` from Task 4 and the `--syntax-*` tokens from Task 2.
- Produces: the descendant rules under `.tty-prose`, the `pre[class*="language-"]` and
  `code[class*="language-"]` rules, the Prism `.token.*` colour map, and the
  `div.code-toolbar` layout and chrome. No new class name that other tasks call.
- Produces the anchor offset: every `.tty-prose` heading gets
  `scroll-margin-top: calc(52px + var(--sp-4))`, so a `#heading-id` link from the
  Markdown anchor plugin does not land under the 52px sticky nav.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "prose and code"
have "styles/tty/prose.css"
have "styles/tty/prism-tty.css"
grep_in "styles/tty.css" '@import "tty/prose.css"' "the entry stylesheet imports prose.css"
grep_in "styles/tty.css" '@import "tty/prism-tty.css"' "the entry stylesheet imports prism-tty.css"
grep_in "styles/tty/prose.css" "scroll-margin-top" "heading anchors clear the sticky nav"
grep_in "styles/tty/prose.css" "border-left: var(--border-w-thick) solid var(--yellow)" "the blockquote rule is a 2px yellow bar"
grep_in "styles/tty/prose.css" ".tty-prose .katex-display" "display maths scrolls instead of overflowing"
grep_in "styles/tty/prose.css" ".tty-prose h1 {" "a markdown h1 is styled"
grep_in "styles/tty/prose.css" "text-transform: none" "inline code in a heading keeps its case"
grep_in "styles/tty/prose.css" 'pre:not([class*="language-"])' "an unlabelled fence gets the code chrome"
grep_in "styles/tty/prose.css" ':not(pre) > code:not([class*="language-"])' "the inline-code pill stops at a pre"
grep_in "posts/how-linux-kernel-submissions-work/index.html" "<pre><code>" "the unlabelled fence is the case that rule covers"
grep_in "styles/tty/prism-tty.css" "var(--syntax-keyword)" "syntax colours come from the tokens"
grep_in "styles/tty/prism-tty.css" "div.code-toolbar > .toolbar" "the code toolbar is styled locally"
grep_in "styles/tty/prism-tty.css" "order: -1" "the toolbar is a strip above the code"
grep_not "styles/tty/prism-tty.css" "position: absolute" "no chrome floats over the first line of code"
grep_in "styles/tty/prism-tty.css" "button:focus-visible" "the copy button keeps a focus ring"
grep_in "styles/tty/prism-tty.css" "text-shadow: none" "the Prism theme text shadow is off"
grep_not "styles/tty/prism-tty.css" "border-radius: 0.25rem" "code blocks are square"
```

Add one more assertion in the same section — it proves the CDN toolbar stylesheet is gone
from a page that actually has code. Pick a post that contains a fenced block;
`posts/how-to-setup-lkd-notes/index.html` does.

```bash
grep_in "posts/how-to-setup-lkd-notes/index.html" 'class="language-' "the post still ships highlighted code"
grep_not "posts/how-to-setup-lkd-notes/index.html" "prism-toolbar.min.css" "the CDN toolbar stylesheet is gone"
grep_in "posts/how-to-setup-lkd-notes/index.html" "prism-toolbar.min.js" "the toolbar script is still injected"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — two missing files, plus `the CDN toolbar stylesheet is gone`.

- [ ] **Step 3: Write the prose CSS**

Create `src/styles/tty/prose.css`:

```css
/* Long-form reading inside .tty-prose.

   The design system Post screen sets h1 and h2 in Silkscreen and leaves the
   body plain. Three posts open sections with `# ` — 22 headings in all — and the
   posts nest headings four deep. So h1 and h2 both keep Silkscreen in yellow,
   h1 one step up the display scale, and h3 to h6 step down into JetBrains Mono.
   tokens/base.css puts every h1-h6 in the pixel face and uppercases them, so
   each of those rules has to switch the family and turn smoothing back on, and
   one more rule has to put the case back for inline code inside a heading.

   The system says there is no imagery, by design. That rule is about
   decoration. These posts carry real figures — screenshots and plots — so a
   figure gets a 1px rule and nothing else. */

.tty-prose > :first-child { margin-top: 0; }
.tty-prose > :last-child { margin-bottom: 0; }

.tty-prose p { margin: 0 0 var(--sp-6); }
.tty-prose strong { color: var(--text-primary); font-weight: var(--weight-bold); }
.tty-prose em { font-style: italic; }

/* ── Headings ───────────────────────────────────────────────────────────── */
.tty-prose h1,
.tty-prose h2,
.tty-prose h3,
.tty-prose h4,
.tty-prose h5,
.tty-prose h6 {
  scroll-margin-top: calc(52px + var(--sp-4));
}

/* Three posts use `# ` for their section headings. With no rule here those fall
   through to tokens/base.css and the UA default: 2em grey Silkscreen, which is
   both larger and dimmer than the h2 under it. h1 gets the top of the display
   scale so the hierarchy reads down. */
.tty-prose h1 {
  margin: var(--sp-12) 0 var(--sp-4);
  font-family: var(--font-display);
  font-size: var(--display-md);
  line-height: var(--leading-tight);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--yellow);
  -webkit-font-smoothing: none;
  font-smooth: never;
}

.tty-prose h2 {
  margin: var(--sp-10) 0 var(--sp-4);
  font-family: var(--font-display);
  font-size: var(--display-sm);
  line-height: var(--leading-tight);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--yellow);
  -webkit-font-smoothing: none;
  font-smooth: never;
}

.tty-prose h3 {
  margin: var(--sp-8) 0 var(--sp-3);
  font-family: var(--font-body);
  font-size: var(--text-lg);
  font-weight: var(--weight-bold);
  line-height: var(--leading-ui);
  letter-spacing: var(--tracking-label);
  text-transform: uppercase;
  color: var(--text-primary);
  -webkit-font-smoothing: antialiased;
  font-smooth: auto;
}

.tty-prose h4,
.tty-prose h5,
.tty-prose h6 {
  margin: var(--sp-6) 0 var(--sp-2);
  font-family: var(--font-body);
  font-size: var(--text-md);
  font-weight: var(--weight-medium);
  line-height: var(--leading-ui);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-muted);
  -webkit-font-smoothing: antialiased;
  font-smooth: auto;
}

/* Every rule above uppercases the heading, and tokens/base.css uppercases h1-h6
   anyway. Inline code in a heading is a case-sensitive name, so it must keep the
   case the author typed. Five real cases exist today: `git blame`, `activate.sh`,
   `guards`, `scoped_guard` and `null_blk`. Uppercasing them makes the page state
   something false and gives a reader the wrong name to copy. The tracking has to
   go too, or the name reads with gaps in it. */
.tty-prose :is(h1, h2, h3, h4, h5, h6) code {
  text-transform: none;
  letter-spacing: 0;
}

/* ── Lists ──────────────────────────────────────────────────────────────── */
.tty-prose ul,
.tty-prose ol { margin: 0 0 var(--sp-6); padding-left: var(--sp-6); }
.tty-prose li { margin: 0 0 var(--sp-2); }
.tty-prose li > ul,
.tty-prose li > ol { margin: var(--sp-2) 0 0; }
.tty-prose ul { list-style: none; padding-left: var(--sp-5); }
.tty-prose ul > li { position: relative; }
/* A block marker on the cell grid, not a round bullet. U+25AA is outside the
   latin subset tokens/fonts.css loads, so this glyph comes from the system
   fallback, not from JetBrains Mono. Pin the size and the leading so fallback
   metrics cannot move it off the first text line of the item. */
.tty-prose ul > li::before {
  content: "▪";
  position: absolute;
  left: calc(var(--sp-5) * -1);
  font-family: var(--font-glyph);
  font-size: 0.85em;
  line-height: var(--leading-body);
  color: var(--text-faint);
}
.tty-prose ol { list-style: decimal; }
.tty-prose ol > li::marker { color: var(--text-faint); }

/* ── Quote ──────────────────────────────────────────────────────────────── */
.tty-prose blockquote {
  margin: var(--sp-8) 0;
  padding: 4px 0 4px 18px;
  border-left: var(--border-w-thick) solid var(--yellow);
  color: var(--text-primary);
  font-size: var(--text-md);
  line-height: 1.75;
}
.tty-prose blockquote > :last-child { margin-bottom: 0; }

/* ── Rule ───────────────────────────────────────────────────────────────── */
.tty-prose hr {
  margin: var(--sp-10) 0;
  border: 0;
  border-top: var(--border-w) solid var(--border-faint);
}

/* ── Inline code ────────────────────────────────────────────────────────── */
/* `:not(pre) >` keeps the pill off the `<code>` inside an unlabelled fence. That
   `<code>` carries no class either, so the plain `code:not([class*="language-"])`
   form matched it and drew a 0.9em bordered band over a 242-line git diff. Real
   inline code always has a parent element inside .tty-prose — a p, li, td or
   heading — so the guard never costs a match. */
.tty-prose :not(pre) > code:not([class*="language-"]) {
  padding: 1px 5px;
  font-family: var(--font-code);
  font-size: 0.9em;
  color: var(--text-primary);
  background: var(--surface-raised);
  border: var(--border-w) solid var(--border-faint);
}

/* ── A fence with no language ────────────────────────────────────────────── */
/* Four fences in two posts carry no info string, so the syntax highlight plugin
   gives them no `language-*` class and every rule in prism-tty.css misses them.
   This rule gives that case the same chrome as a labelled block. `overflow: auto`
   is the part that must not be dropped: tokens/breakpoints.css ends with
   `html, body { overflow-x: hidden }`, so a block with no scroller of its own has
   its long lines clipped with no scrollbar anywhere — a 99-character diff line
   and a 120-character `git send-email` command are both affected. */
.tty-prose pre:not([class*="language-"]) {
  margin: 0 0 var(--sp-6);
  padding: 10px 12px;
  font-family: var(--font-code);
  font-size: var(--text-sm);
  line-height: 1.7;
  tab-size: 2;
  hyphens: none;
  overflow: auto;
  color: var(--text-secondary);
  background: var(--surface-inset);
  border: var(--border-w) solid var(--border-faint);
  border-radius: var(--radius-none);
}
.tty-prose pre:not([class*="language-"]) > code {
  padding: 0;
  font-family: inherit;
  font-size: inherit;
  line-height: inherit;
  color: inherit;
  background: none;
  border: 0;
  white-space: pre;
}

/* ── Figures ────────────────────────────────────────────────────────────── */
.tty-prose img {
  display: block;
  max-width: 100%;
  height: auto;
  margin: var(--sp-8) auto;
  border: var(--border-w) solid var(--border-faint);
}

/* ── Tables ─────────────────────────────────────────────────────────────── */
.tty-prose table {
  width: 100%;
  margin: 0 0 var(--sp-6);
  border-collapse: collapse;
  font-size: var(--text-sm);
}
.tty-prose thead th {
  height: 26px;
  padding: 0 10px;
  text-align: left;
  font: var(--text-xs)/1 var(--font-display);
  letter-spacing: var(--tracking-label);
  text-transform: uppercase;
  color: var(--text-faint);
  background: var(--surface-raised);
  border-bottom: var(--border-w) solid var(--border-default);
  -webkit-font-smoothing: none;
  font-smooth: never;
}
.tty-prose tbody tr { height: var(--row-h); }
.tty-prose tbody tr:nth-child(even) { background: var(--surface-raised); }
.tty-prose tbody td {
  padding: var(--sp-2) 10px;
  border-bottom: var(--border-w) solid var(--border-faint);
  color: var(--text-primary);
}

/* ── Maths ──────────────────────────────────────────────────────────────── */
.tty-prose .katex { font-size: 1em; }
.tty-prose .katex-display {
  margin: var(--sp-6) 0;
  padding: var(--sp-2) 0;
  overflow-x: auto;
  overflow-y: hidden;
}
```

- [ ] **Step 4: Write the Prism CSS**

Create `src/styles/tty/prism-tty.css`:

```css
/* Prism, mapped onto the TTY syntax tokens.
   Replaces the prism-tomorrow CDN theme and the prism-toolbar CDN stylesheet.
   The toolbar plugin's JavaScript only positions itself if these layout rules
   exist, so they live here rather than on the CDN — that also keeps the CDN
   from overriding our chrome, since .eleventy.js injects its block before
   </body>. */

pre[class*="language-"] {
  margin: 0 0 var(--sp-6);
  padding: 10px 12px;
  font-family: var(--font-code);
  font-size: var(--text-sm);
  line-height: 1.7;
  tab-size: 2;
  hyphens: none;
  overflow: auto;
  color: var(--text-secondary);
  background: var(--surface-inset);
  border: var(--border-w) solid var(--border-faint);
  border-radius: var(--radius-none);
  text-shadow: none;
}
code[class*="language-"] {
  font-family: var(--font-code);
  font-size: inherit;
  line-height: inherit;
  color: var(--text-secondary);
  background: transparent;
  text-shadow: none;
  white-space: pre;
}
pre[class*="language-"]::selection,
pre[class*="language-"] ::selection,
code[class*="language-"]::selection,
code[class*="language-"] ::selection {
  background: var(--yellow);
  color: var(--black-void);
  text-shadow: none;
}

/* ── Token colours ──────────────────────────────────────────────────────── */
.token.comment,
.token.prolog,
.token.doctype,
.token.cdata { color: var(--syntax-comment); font-style: italic; }

.token.punctuation,
.token.operator,
.token.entity { color: var(--syntax-punct); }

.token.number,
.token.boolean,
.token.constant,
.token.symbol { color: var(--syntax-number); }

.token.string,
.token.char,
.token.attr-value,
.token.inserted { color: var(--syntax-string); }

.token.keyword,
.token.atrule,
.token.rule,
.token.selector,
.token.tag,
.token.important { color: var(--syntax-keyword); }

.token.function,
.token.function-name,
.token.class-name { color: var(--syntax-function); }

.token.property,
.token.attr-name,
.token.builtin,
.token.regex,
.token.url { color: var(--cyan); }

.token.variable,
.token.parameter { color: var(--text-primary); }

.token.deleted { color: var(--status-error); }

.token.bold,
.token.important { font-weight: var(--weight-bold); }
.token.italic { font-style: italic; }
.token.namespace { opacity: 0.7; }

/* ── Toolbar: language badge and copy button ─────────────────────────────── */
/* CodeBlock.jsx puts the label in a 26px strip above the code, inside the block
   border. The system never floats chrome over content, so this is a strip, not an
   overlay. prism-toolbar.js appends the toolbar *after* the `<pre>`, so the
   container is a column flex box and the strip is pulled up with `order: -1`.
   Nothing here is absolutely positioned, so nothing can cover line 1. */
div.code-toolbar {
  display: flex;
  flex-direction: column;
  margin: 0 0 var(--sp-6);
  background: var(--surface-inset);
  border: var(--border-w) solid var(--border-faint);
}
/* The container draws the frame now, so the inner pre gives its own back. */
div.code-toolbar > pre[class*="language-"] {
  margin: 0;
  background: transparent;
  border: 0;
}
div.code-toolbar > .toolbar {
  order: -1;
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  height: 26px;
  padding: 0 10px;
  background: var(--surface-raised);
  border-bottom: var(--border-w) solid var(--border-faint);
  opacity: 1;
}
/* show-language adds the first item and copy-to-clipboard the second. The
   language takes CodeBlock's filename slot on the left; the button goes right. */
div.code-toolbar > .toolbar > .toolbar-item { display: flex; align-items: center; }
div.code-toolbar > .toolbar > .toolbar-item:first-child { margin-right: auto; }
div.code-toolbar > .toolbar > .toolbar-item > a,
div.code-toolbar > .toolbar > .toolbar-item > button,
div.code-toolbar > .toolbar > .toolbar-item > span {
  padding: 0;
  font-family: var(--font-body);
  font-size: var(--text-xs);
  letter-spacing: 0.08em;
  color: var(--text-faint);
  background: none;
  border: 0;
  border-radius: var(--radius-none);
  cursor: pointer;
  user-select: none;
}
div.code-toolbar > .toolbar > .toolbar-item > a:hover,
div.code-toolbar > .toolbar > .toolbar-item > button:hover {
  color: var(--yellow);
}
/* tokens/base.css drops the outline and draws focus with a box-shadow. Never set
   `box-shadow: none` on these items — that wins on specificity and leaves the
   Copy button with no keyboard focus indicator at all. */
div.code-toolbar > .toolbar > .toolbar-item > a:focus-visible,
div.code-toolbar > .toolbar > .toolbar-item > button:focus-visible {
  color: var(--yellow);
  box-shadow: var(--focus-ring);
}
/* The language badge is a label, not a control. CodeBlock.jsx sets it in accent. */
div.code-toolbar > .toolbar > .toolbar-item > span {
  color: var(--text-accent);
  cursor: default;
}
```

- [ ] **Step 5: Drop the CDN toolbar stylesheet**

In `.eleventy.js`, inside the `PRISM_PLUGIN_BLOCK` template literal, delete this one line:

```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/prismjs@1/plugins/toolbar/prism-toolbar.min.css">
```

Leave every `<script>` line in that block alone. The toolbar and copy-button JavaScript
still have to load.

- [ ] **Step 6: Add the imports**

In `src/styles/tty.css`, add two lines after the `tty/layout.css` import:

```css
@import "tty/prose.css";
@import "tty/prism-tty.css";
```

Order does not decide this cascade. `pre[class*="language-"]` at (0,1,1) beats
`tokens/base.css`'s `code, pre, kbd, samp` at (0,0,1) from any position, and the bare-fence
rule Step 3 adds is `.tty-prose pre:not([class*="language-"])`, which can never match the
same element. Keep `prism-tty.css` last so the two code stylesheets read in order. The one
order that did matter is the CDN toolbar stylesheet, and Step 5 deletes it.

**Task 6 does not finish the prose work.** Task 17 covers the Markdown these posts actually
contain — wide tables, task lists, centred figure captions. Run Task 17 after Task 8, not
after this task: Task 8 is what puts the post body inside `.tty-prose`, and every rule
Task 17 writes is scoped to that class. Read it before you decide `prose.css` is done.

- [ ] **Step 7: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 8: Look at a code block**

Run: `bun run start` and open
`http://localhost:8080/posts/how-to-setup-lkd-notes/`.
Expect: square code blocks on `#000000` inside a 1px rule, magenta keywords, green
strings, cyan numbers, and a grey italic comment. Above each block sits a 26px strip with
the language on the left in yellow and a `copy` button on the right. The strip must not
cover line 1 of the code. Tab to the `copy` button: it must show a yellow focus ring.

Check three more things on the same page:
1. The seven `#` headings are yellow Silkscreen and larger than the `##` headings under
   them.
2. Every bulleted list marker sits on the first text line of its item, not above it and
   not below it.
3. The heading `The so-called activate.sh` keeps the file name in lower case.

Then open `http://localhost:8080/posts/how-linux-kernel-submissions-work/` and find the
long git-diff block, which has no language label and so gets no header strip. It must show
the same background, 1px border, padding and small font as a labelled block, and its own
horizontal scrollbar. Narrow the window to 380px and confirm you can still scroll that
block to the end of the 120-character `git send-email` line.

The article body is still the old markup — Task 8 fixes it. Stop the server before you run
the check again.

- [ ] **Step 9: Commit**

```bash
git add src/styles/tty/prose.css src/styles/tty/prism-tty.css src/styles/tty.css .eleventy.js scripts/check-build.sh
git commit -m "feat(design): style long-form prose and syntax highlighting

Markdown bodies get the design system treatment: h1 and h2 in Silkscreen
yellow, h3 and below in JetBrains Mono, block list markers, a 2px yellow quote
rule, 1px figure frames, dense tables and scrollable display maths. Inline code
inside a heading keeps the case the author typed, so names like activate.sh and
scoped_guard stay correct. A fence with no language gets the same chrome as a
labelled one and its own scroller, because the page clips sideways overflow.
Headings carry a scroll-margin so an anchor link clears the sticky nav.

Prism moves off the prism-tomorrow CDN theme onto the --syntax-* tokens. The
toolbar stylesheet comes off the CDN too, because .eleventy.js injects that
link before </body> and it was overriding our chrome. The language label and the
copy button now sit in a 26px strip above the code, the way CodeBlock.jsx draws
them, instead of floating over line 1."
```

---
### Task 7: Add the data layer for archiving, reading time and ordering

Five filters and one collection. Every screen from here on reads them. The task also
lands the `archived` flag end to end: one post carries it, `/posts/` drops that post, and
the assertions prove both halves.

**Read this before you start.** `archived: true` on a post means "still published, no
longer listed on the landing page". The post keeps its URL, stays in the Atom feed, stays
in `sitemap.xml`, stays in `llms.txt`, and stays in the search index. Only
`/posts/` excludes it, and `/posts/archive/` marks it. That is what the owner asked for:
*exclude the archived posts from /posts/*, nothing wider.

**This task sets `archived: true` on one real post** —
`src/en/posts/my-tools-2024.md`, which `my-tools-2025.md` supersedes. That is the one
worked example, and it is what makes the flag verifiable instead of theoretical. It is a
one-line frontmatter change. **Tell the owner it happened** and offer to revert it; the
rest of the migration does not depend on which post carries the flag.

**Files:**
- Modify: `.eleventy.js` (new collection after line 163, new filters after line 247)
- Modify: `src/en/posts/my-tools-2024.md` (frontmatter, one line)
- Modify: `src/en/posts/index.njk:16` (one line — the collection it loops)
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: the `languages` array already in `.eleventy.js:69`.
- Produces the collection `postsActive_<lang>` — every post under
  `src/<lang>/posts/**/*.md` whose `data.archived` is not `true`, sorted newest first.
  With i18n off that is `postsActive_en` only.
- Produces the filter `readingTime(input) -> string` — accepts either a collection item
  or a rendered HTML string, and returns `"<n> min"` with `n` at least 1, counting 200
  words a minute. Call it as `post | readingTime` from a list page and as
  `content | readingTime` from inside a post layout.
- Produces the filter `groupByYear(posts) -> [{ year: string, posts: item[] }]`, newest
  year first, each group keeping the input order.
- Produces the filter `postIndexes(posts) -> { [url]: string }` — a map from post URL to
  a zero-padded three-digit index that counts *down*, so the newest post in the list is
  the highest number. `PostCard` shows this in the index column.
- Produces the filter `nextPost(posts, url) -> item | null` — the entry after `url` in
  the list, wrapping to the first. Used for the "next" link on a post page.
- Produces the frontmatter key `archived: true`, read by `postsActive_<lang>` and by the
  archive template in Task 11.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "archive flag and data layer"
grep_not "posts/index.html" "Tools I use 2024" "the archived post is off the posts landing page"
# These assertions read the built HTML, not the frontmatter. Nunjucks escapes the
# apostrophe in "Tools I've been using - 2025" to `&#39;`, so grep the part of the
# title that has no apostrophe in it. That stays correct if the escaping changes.
grep_in "posts/index.html" "been using - 2025" "the active posts are still listed"
have "posts/my-tools-2024/index.html"
grep_in "feed.xml" "Tools I use 2024" "the archived post stays in the feed"
grep_in "llms.txt" "Tools I use 2024" "the archived post stays in llms.txt"
grep_in "search-index-en.json" "Tools I use 2024" "the archived post stays searchable"
grep_in "sitemap.xml" "/posts/my-tools-2024/" "the archived post stays in the sitemap"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `the archived post is off the posts landing page`. Every other line in
the section already passes, because the post is published today.

- [ ] **Step 3: Add the collection**

In `.eleventy.js`, directly after the `posts_${lang}` collection loop that ends at line
163, add:

```js
  // Posts that still belong on the /posts/ landing page.
  // `archived: true` in a post's frontmatter drops it from here. The post keeps
  // its URL and stays in the feed, the sitemap, llms.txt and the search index —
  // only the landing page hides it, and /posts/archive/ marks it.
  languages.forEach((lang) => {
    eleventyConfig.addCollection(`postsActive_${lang}`, (collectionApi) => {
      return collectionApi.getFilteredByGlob(`src/${lang}/posts/**/*.md`)
        .filter((post) => post.data.archived !== true)
        .sort((a, b) => b.data.date - a.data.date);
    });
  });
```

- [ ] **Step 4: Add the filters**

In `.eleventy.js`, directly after the `filterByTag` filter that ends at line 247, add:

```js
  /** Words in a rendered HTML string, tags stripped. */
  function wordCount(html) {
    return String(html || "")
      .replace(/<[^>]+>/g, " ")
      .split(/\s+/)
      .filter(Boolean).length;
  }

  // Reading time at 200 words a minute, floored at one minute.
  // Takes either a collection item (from a list page) or the rendered HTML
  // string (from inside a post layout, where only `content` is in scope).
  eleventyConfig.addFilter("readingTime", (input) => {
    const html = typeof input === "string"
      ? input
      : (input && (input.templateContent || input.content)) || "";
    return `${Math.max(1, Math.round(wordCount(html) / 200))} min`;
  });

  // [{ year, posts }], newest year first, input order kept inside each year.
  eleventyConfig.addFilter("groupByYear", (posts) => {
    const groups = new Map();
    (posts || []).forEach((post) => {
      const year = String(post.date.getFullYear());
      if (!groups.has(year)) groups.set(year, []);
      groups.get(year).push(post);
    });
    return [...groups.entries()]
      .sort((a, b) => b[0].localeCompare(a[0]))
      .map(([year, items]) => ({ year, posts: items }));
  });

  // url -> "013". The index counts down, so the newest post carries the highest
  // number. Templates that group by year still need a global index, which is why
  // this is a map and not a loop counter.
  eleventyConfig.addFilter("postIndexes", (posts) => {
    const map = {};
    const list = posts || [];
    list.forEach((post, i) => {
      map[post.url] = String(list.length - i).padStart(3, "0");
    });
    return map;
  });

  // The entry after `url`, wrapping to the first. Drives the "next" link on a
  // post page. Returns null when the url is not in the list.
  eleventyConfig.addFilter("nextPost", (posts, url) => {
    if (!Array.isArray(posts) || posts.length === 0) return null;
    const i = posts.findIndex((post) => post.url === url);
    if (i < 0) return null;
    return posts[(i + 1) % posts.length] || null;
  });
```

- [ ] **Step 5: Archive one post**

In `src/en/posts/my-tools-2024.md`, add one line to the frontmatter, directly under
`place: brazil`:

```yaml
archived: true
```

- [ ] **Step 6: Point the landing page at the active collection**

In `src/en/posts/index.njk`, change line 16 from

```njk
{% for post in collections.posts %}
```

to

```njk
{% for post in collections.postsActive_en %}
```

Leave the rest of that template alone — Task 9 rewrites it.

- [ ] **Step 7: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 8: Prove the filters by hand**

The filters have no template yet, so check them with a throwaway page rather than trusting
the code by eye. Create `src/en/_filtercheck.njk` with this content:

```njk
---
layout: null
permalink: /_filtercheck.txt
eleventyExcludeFromCollections: true
---
{%- set idx = collections.postsActive_en | postIndexes -%}
count={{ collections.postsActive_en.length }}
first-index={{ idx[collections.postsActive_en[0].url] }}
first-reading={{ collections.postsActive_en[0] | readingTime }}
next-after-first={{ (collections.postsActive_en | nextPost(collections.postsActive_en[0].url)).data.title }}
{% for group in collections.postsActive_en | groupByYear %}year={{ group.year }} n={{ group.posts.length }}
{% endfor %}
```

Run: `bun run build && cat dist/_filtercheck.txt`
Expected: `count=13`, `first-index=013`, a `first-reading` like `4 min`, a
`next-after-first` title, and one `year=` line per year present, `2026` first.

Then delete the throwaway page — it was a probe, not a feature:

```bash
rm src/en/_filtercheck.njk
```

- [ ] **Step 9: Commit**

```bash
git add .eleventy.js src/en/posts/my-tools-2024.md src/en/posts/index.njk scripts/check-build.sh
git commit -m "feat(blog): add the archive flag, reading time and list ordering

postsActive_<lang> drops any post whose frontmatter sets archived: true. An
archived post keeps its URL and stays in the feed, the sitemap, llms.txt and
the search index; only the /posts/ landing page hides it.

Four filters come with it: readingTime (item or html string), groupByYear,
postIndexes (url -> padded descending index) and nextPost. The 2024 tools post
carries the flag as the worked example, since the 2025 post supersedes it."
```

---
### Task 8: Rebuild the post page

The `Post.jsx` screen: a centred column at the 68ch measure, a meta row with a
reading-progress readout, the title in Silkscreen, tag links, the prose body, and a
"next" link with a blinking caret. Archived posts get a banner.

**Files:**
- Create: `src/scripts/tty-progress.js`
- Create: `src/_includes/archivedBanner.njk`
- Modify: `src/_includes/layouts/post.njk` (full rewrite)
- Modify: `src/_includes/translationWarning.njk` (full rewrite)
- Modify: `src/styles/tty/layout.css` (append the post screen block)
- Modify: `src/_data/i18n/en.json`
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `.tty-prose`, `.tty-caret` (Task 4), `.tty-rule`, `.tty-tag`, `.tty-badge`
  (Task 3), `tty.tag` macro (Task 3), `readingTime` and `nextPost` filters (Task 7), the
  `tagSlug` filter (already in `.eleventy.js:116`), the `postDate` filter
  (`.eleventy.js:320`).
- Produces the CSS classes appended to `layout.css`: `.tty-post`, `.tty-post__head`,
  `.tty-post__meta`, `.tty-post__back`, `.tty-post__progress`, `.tty-post__tags`,
  `.tty-post__body`, `.tty-post__foot`, `.tty-post__next`, `.tty-note`
  (`.tty-note--warn`, `.tty-note__title`, `.tty-note__body`).
- Produces `src/scripts/tty-progress.js` — reads every `[data-tty-progress]` element and
  writes the scroll percentage into it. Loaded only by `post.njk`.
- Produces `src/_includes/archivedBanner.njk` — renders nothing unless `archived` is
  true.
- Produces the i18n keys `post.updatedOn`, `post.backToPosts`, `post.next`,
  `post.archived.title`, `post.archived.message`, `post.translationWarning.title`,
  `post.translationWarning.message`.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "post page"
have "scripts/tty-progress.js"
grep_in "posts/my-tools-2025/index.html" 'class="tty-post"' "the post screen wrapper is present"
grep_in "posts/my-tools-2025/index.html" 'data-tty-progress' "the reading progress readout is present"
grep_in "posts/my-tools-2025/index.html" 'class="tty-prose' "the body is inside the prose wrapper"
grep_in "posts/my-tools-2025/index.html" 'class="tty-post__next"' "the next-post link is present"
grep_in "posts/my-tools-2025/index.html" 'class="tty-caret"' "the caret closes the post"
grep_in "posts/my-tools-2025/index.html" '/posts/tag/' "tag links are present"
grep_in "posts/my-tools-2025/index.html" '/scripts/tty-progress.js' "the progress script is loaded"
grep_not "posts/my-tools-2025/index.html" 'class="post-meta"' "the old Pico meta row is gone"
grep_not "posts/my-tools-2025/index.html" 'class="tag-pill"' "the old tag pills are gone"
grep_in "posts/my-tools-2024/index.html" 'class="tty-note tty-note--warn"' "the archived post shows a banner"
grep_not "posts/my-tools-2025/index.html" 'class="tty-note tty-note--warn"' "an active post shows no banner"
grep_in "styles/tty/layout.css" ".tty-post__progress" "the post screen CSS is present"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `file scripts/tty-progress.js is missing` plus twelve more.

- [ ] **Step 3: Append the post screen CSS**

Append to `src/styles/tty/layout.css`:

```css
/* ── Post screen (ui_kits/blog/Post.jsx) ────────────────────────────────── */
.tty-post { display: flex; flex-direction: column; align-items: center; }
/* 68ch must be counted in the reading face. The head, the body and the foot all
   carry --text-lg, so the three columns come out at the same width. Every child
   sets its own font-size, so nothing else grows. */
.tty-post__head,
.tty-post__body,
.tty-post__foot { width: 100%; max-width: var(--measure-prose); font-size: var(--text-lg); }
/* One measure, not two: .tty-prose must not constrain this column again. */
.tty-post__body .tty-prose { max-width: none; }

.tty-post__meta {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  font-size: var(--text-xs);
  color: var(--text-faint);
}
.tty-post__back { color: var(--text-muted); border-bottom-color: var(--border-default); }
.tty-post__back:hover { color: var(--yellow); }
/* The one live number on a reading page. It ships empty, so it holds its own
   width and the meta row does not reflow when the script fills it. */
.tty-post__progress {
  min-width: 4ch;
  text-align: right;
  color: var(--yellow);
  font-variant-numeric: tabular-nums;
}

.tty-post__head .tty-h1 {
  margin: 20px 0 0;
  font-size: var(--display-lg);
  line-height: 1.15;
  letter-spacing: 0.04em;
}
.tty-post__tags { display: flex; flex-wrap: wrap; gap: 7px; margin-top: 18px; }
.tty-post__head .tty-rule { margin: 26px 0 30px; }

.tty-post__foot { margin-top: var(--sp-12); }
.tty-post__foot .tty-rule { margin-bottom: 20px; }
.tty-post__foot .tty-post__meta { gap: 16px; }
.tty-post__next {
  font-family: var(--font-display);
  font-size: var(--display-xs);
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--yellow);
  -webkit-font-smoothing: none;
  font-smooth: never;
  border-bottom-color: var(--yellow-dim);
}
.tty-post__next:hover { color: var(--yellow-bright); }

/* ── Note banner (archived post, machine-translated post) ───────────────── */
.tty-note {
  margin: 0 0 var(--sp-8);
  padding: var(--sp-3) var(--sp-4);
  background: var(--surface-panel);
  border: var(--border-w) solid var(--border-default);
  border-left: var(--border-w-thick) solid var(--border-strong);
}
.tty-note--warn { border-left-color: var(--status-warn); }
.tty-note__title {
  display: block;
  font-family: var(--font-display);
  font-size: 12px;
  letter-spacing: var(--tracking-label);
  text-transform: uppercase;
  color: var(--status-warn);
  -webkit-font-smoothing: none;
  font-smooth: never;
}
.tty-note__body {
  margin: var(--sp-2) 0 0;
  font-size: var(--text-sm);
  line-height: 1.6;
  color: var(--text-muted);
}
```

- [ ] **Step 4: Write the progress script**

Create `src/scripts/tty-progress.js`:

```js
/* Reading progress for a post page. Writes a whole-number percentage into every
   [data-tty-progress] element. No dependency, no framework.

   The listener is passive and the write is coalesced into one animation frame,
   so a fast scroll does not queue a layout read per event. */
(function () {
  var targets = document.querySelectorAll("[data-tty-progress]");
  if (targets.length === 0) return;

  var queued = false;

  function paint() {
    queued = false;
    var el = document.scrollingElement || document.documentElement;
    var span = el.scrollHeight - el.clientHeight;
    var pct = span <= 0 ? 100 : Math.round((el.scrollTop / span) * 100);
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    for (var i = 0; i < targets.length; i++) {
      targets[i].textContent = pct + "%";
    }
  }

  function onScroll() {
    if (queued) return;
    queued = true;
    window.requestAnimationFrame(paint);
  }

  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll, { passive: true });
  paint();
})();
```

- [ ] **Step 5: Write the archived banner**

Create `src/_includes/archivedBanner.njk`:

```njk
{% if archived %}
<aside class="tty-note tty-note--warn" role="note">
  <span class="tty-note__title">{{ i18n[locale].post.archived.title }}</span>
  <p class="tty-note__body">{{ i18n[locale].post.archived.message }}</p>
</aside>
{% endif %}
```

- [ ] **Step 6: Rewrite the translation warning**

Replace the whole of `src/_includes/translationWarning.njk` with:

```njk
{% if locale and locale != "en" %}
<aside class="tty-note tty-note--warn" role="note">
  <span class="tty-note__title">{{ i18n[locale].post.translationWarning.title }}</span>
  <p class="tty-note__body">{{ i18n[locale].post.translationWarning.message }}</p>
</aside>
{% endif %}
```

The robot emoji is gone. The design system forbids emoji, and this banner renders nothing
today anyway, because `I18N_ENABLED` is `false`.

- [ ] **Step 7: Rewrite the post layout**

Replace the whole of `src/_includes/layouts/post.njk` with:

```njk
---
layout: layouts/layout.njk
type: blogPost
ogType: article
---
{% import "tty/core.njk" as tty %}
{%- set siblings = collections['postsActive_' + (locale or 'en')] -%}
{%- set next = siblings | nextPost(page.url) -%}
<article class="tty-post">
  <header class="tty-post__head">
    <div class="tty-post__meta">
      <a class="tty-post__back" href="{{ '/posts' | i18nUrl(locale) }}/">← {{ i18n[locale].post.backToPosts }}</a>
      <span aria-hidden="true">·</span>
      <time datetime="{{ date.toISOString() }}">{{ date | postDate }}</time>
      {% if modified %}
      <span aria-hidden="true">·</span>
      <time datetime="{{ modified.toISOString() }}">{{ i18n[locale].post.updatedOn }} {{ modified | postDate }}</time>
      {% endif %}
      <span aria-hidden="true">·</span>
      <span>{{ content | readingTime }}</span>
      <span class="tty-spacer"></span>
      <span class="tty-post__progress" data-tty-progress aria-hidden="true"></span>
    </div>
    <h1 class="tty-h1">{{ title }}</h1>
    {% if tags and tags.length %}
    <div class="tty-post__tags">
      {%- for tag in tags -%}
        {{ tty.tag(tag, ('/posts/tag/' | i18nUrl(locale)) + (tag | tagSlug) + '/') }}
      {%- endfor -%}
    </div>
    {% endif %}
    <hr class="tty-rule">
  </header>

  <div class="tty-post__body">
    {% include "archivedBanner.njk" %}
    {% include "translationWarning.njk" %}
    <div class="tty-prose">
      {{ content | safe }}
    </div>
  </div>

  {% if next %}
  <footer class="tty-post__foot">
    <hr class="tty-rule">
    <div class="tty-post__meta">
      <span>{{ i18n[locale].post.next }}</span>
      <a class="tty-post__next" href="{{ next.url }}">{{ next.data.title }}</a>
      <span class="tty-caret" aria-hidden="true"></span>
    </div>
  </footer>
  {% endif %}
</article>
<script defer src="/scripts/tty-progress.js"></script>
```

Two notes:

- `nextPost` runs over `postsActive_<lang>`, so an archived post has no "next" link.
  That is correct: an archived post is not part of the reading sequence any more. The
  `{% if next %}` guard covers it.
- `i18nUrl` returns the URL unchanged while the locale is `en`, so `/posts/` and
  `/posts/tag/<slug>/` are what actually render today.

- [ ] **Step 8: Confirm the i18n strings are already there**

This task writes no i18n string. Task 5 Step 7 owns `src/_data/i18n/en.json` and already
lands every `post.*` key at its final value. Confirm, rather than edit:

```bash
python3 -c "import json;d=json.load(open('src/_data/i18n/en.json'));print(sorted(d['post']))"
```

Expected: `['archived', 'backToPosts', 'next', 'publishedOn', 'translationWarning', 'updatedOn']`.
If a key is missing, Task 5 was skipped or edited. Fix it there, not here — two tasks writing
the same file is how a key gets silently dropped.

- [ ] **Step 9: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 10: Look at a post**

Run: `bun run start`. Open `http://localhost:8080/posts/my-tools-2025/`.
Expect: a 68ch column, the meta row with a yellow percentage that reads `0%` at the top and
climbs as you scroll, the title in Silkscreen, square tag chips, styled code blocks, and a
`next` link with a blinking caret at the foot. Then open
`http://localhost:8080/posts/my-tools-2024/` and expect the `ARCHIVED` banner with a yellow
left rule and no `next` link.

Then turn JavaScript off and reload the first post. The percentage must be **absent**, not a
false `0%`, and the meta row must not change width when you turn JavaScript back on. The
markup ships the span empty and `tty-progress.js` owns every character in it.
Stop the server before you run the check again.

- [ ] **Step 11: Commit**

```bash
git add src/scripts/tty-progress.js src/_includes src/styles/tty/layout.css src/_data/i18n/en.json scripts/check-build.sh
git commit -m "feat(blog): rebuild the post page on the design system

The Post screen: a 68ch column, a meta row with a live reading-progress
percentage, the title in Silkscreen, square tag chips, and a next link closed
by a blinking caret. An archived post shows a banner and drops out of the
next-post sequence. The translation banner loses its emoji."
```

---
### Task 9: Replace search with the `/` overlay

The design system search is a `/`-key overlay, not an input on the page. This task fills
the `searchOverlay.njk` stub from Task 5, writes the replacement script, and takes the
in-content search box off `/posts/`.

Search stays working the whole way through. Task 5 deleted `header.njk`, which held the
mobile input, but the in-content input and `search.js` kept working. This task swaps both
in one commit, so there is no window where search is broken.

FlexSearch loads lazily, on first open, from the same CDN as before. Pages that never open
the overlay pay nothing. If the CDN fails, the script falls back to substring matching
over the same JSON.

**Files:**
- Create: `src/scripts/tty-search.js`
- Modify: `src/_includes/searchOverlay.njk` (the empty stub from Task 5)
- Modify: `src/en/posts/index.njk` (remove the search root and the two script tags)
- Modify: `.eleventy.js` (one field: the search index must carry the post date)
- Modify: `scripts/check-build.sh`
- Delete: `src/scripts/search.js`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `.tty-search*` classes (Task 5), `.tty-input`, `.tty-menu`, `.tty-spacer`,
  `tty.keyhint` (Task 3), the `i18n[locale].search.*` strings (Task 5), and
  `/search-index-<locale>.json`, which `src/search-index.njk` already generates.
- Produces the DOM contract `tty-search.js` depends on. Do not rename any of these:
  - `#tty-search` — the overlay root. Carries `hidden`, `data-locale`, and the three
    `data-s-*` label attributes.
  - `#tty-search-input` — the query field.
  - `#tty-search-results` — the `<ul class="tty-menu">` the script fills.
  - `#tty-search-count` — the result count readout.
  - `[data-tty-search-open]` — any element that opens the overlay. `nav.njk` already
    carries one.
  - `[data-tty-search-close]` — any element inside the overlay that closes it.
  - `html.tty-search-open` and `body.tty-search-open` — both set while the overlay is
    open, to stop the page scrolling. The vendored `breakpoints.css` sets
    `html, body { overflow-x: hidden }`, so the root element drives the viewport and a
    `hidden` body clips nothing. The class must go on both.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "search overlay"
have "scripts/tty-search.js"
grep_in "index.html" 'id="tty-search"' "the overlay is on every page"
grep_in "index.html" 'id="tty-search-input"' "the query field is present"
grep_in "index.html" 'id="tty-search-results"' "the result list is present"
grep_in "index.html" 'aria-modal="true"' "the overlay is a modal dialog"
grep_in "index.html" 'data-tty-search-close' "the overlay can be dismissed"
grep_in "posts/index.html" 'id="tty-search"' "the overlay reaches the posts page"
grep_not "posts/index.html" 'id="blog-search-input"' "the in-content search box is gone"
grep_not "posts/index.html" 'id="blog-search-root"' "the old search root is gone"
grep_not "posts/index.html" "/scripts/search.js" "the old search script is unlinked"
grep_in "scripts/tty-search.js" "flexsearch.bundle.js" "FlexSearch still backs the query"
grep_in "scripts/tty-search.js" "tty-menu__hint" "each result row carries its date"
grep_in "search-index-en.json" '"date":' "the search index carries a date for every post"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `file scripts/tty-search.js is missing` plus twelve more.

- [ ] **Step 3: Write the overlay markup**

Replace the whole of `src/_includes/searchOverlay.njk` (currently empty) with:

```njk
{% import "tty/core.njk" as tty %}
{#
  The `/` search overlay. It ships on every page, empty, and costs one hidden
  <div> until the reader presses `/`. The index and FlexSearch load on first open.

  The ids and data-* hooks here are a contract with /scripts/tty-search.js.
  Do not rename them without changing that file.
#}
<div class="tty-search" id="tty-search" hidden
     data-locale="{{ locale or 'en' }}"
     data-s-result="{{ i18n[locale].search.result }}"
     data-s-results="{{ i18n[locale].search.results }}"
     data-s-none="{{ i18n[locale].search.noResults }}">
  <div class="tty-search__scrim" data-tty-search-close></div>
  <div class="tty-search__panel" role="dialog" aria-modal="true" aria-label="{{ i18n[locale].search.open }}">
    <div class="tty-search__field">
      <div class="tty-input tty-input--lg">
        <span class="tty-input__prefix" aria-hidden="true">/</span>
        <input id="tty-search-input" type="search" autocomplete="off" spellcheck="false"
               placeholder="{{ i18n[locale].search.placeholder }}"
               aria-label="{{ i18n[locale].search.open }}">
      </div>
    </div>
    <ul class="tty-menu" id="tty-search-results"></ul>
    <div class="tty-search__foot">
      <span id="tty-search-count"></span>
      <span class="tty-spacer"></span>
      {{ tty.keyhint(["↵"], i18n[locale].search.openHint) }}
      {{ tty.keyhint(["esc"], i18n[locale].search.closeHint) }}
    </div>
  </div>
</div>
```

- [ ] **Step 4: Write the search script**

Create `src/scripts/tty-search.js`:

```js
/* The `/` search overlay.
   Replaces scripts/search.js, which drove an input embedded in /posts/.

   FlexSearch and the index load on first open, so a reader who never searches
   downloads neither. If the CDN fails, query() falls back to substring matching
   over the same JSON, which is why the fallback is not an error path. */
(function () {
  var FLEX_URL = "https://cdn.jsdelivr.net/npm/flexsearch@0.7.31/dist/flexsearch.bundle.js";
  var DEBOUNCE_MS = 180;

  var overlay = document.getElementById("tty-search");
  if (!overlay) return;

  var input = document.getElementById("tty-search-input");
  var results = document.getElementById("tty-search-results");
  var countEl = document.getElementById("tty-search-count");
  if (!input || !results || !countEl) return;

  var locale = overlay.getAttribute("data-locale") || "en";
  var LABEL = {
    one: overlay.getAttribute("data-s-result") || "result",
    many: overlay.getAttribute("data-s-results") || "results",
    none: overlay.getAttribute("data-s-none") || "no results"
  };

  var docs = null;      // the raw index JSON
  var index = null;     // the FlexSearch Document, or null
  var rows = [];        // the documents currently rendered
  var hi = 0;           // highlighted row
  var loaded = false;   // the fetch has finished, successfully or not
  var loading = false;
  var timer = null;
  var lastFocus = null;

  /* ── loading ──────────────────────────────────────────────────────────── */

  function loadScript(src) {
    return new Promise(function (resolve) {
      var s = document.createElement("script");
      s.src = src;
      s.onload = function () { resolve(true); };
      s.onerror = function () { resolve(false); };
      document.head.appendChild(s);
    });
  }

  function buildIndex(list) {
    var FS = window.FlexSearch;
    var Document = FS && (FS.Document || (FS.default && FS.default.Document));
    if (!Document || !Array.isArray(list) || list.length === 0) return null;
    try {
      var idx = new Document({
        document: { id: "id", index: ["title", "description", "contentExcerpt"], store: true }
      });
      list.forEach(function (doc) { idx.add(doc); });
      return idx;
    } catch (e) {
      return null;
    }
  }

  function load() {
    if (loaded || loading) return Promise.resolve();
    loading = true;
    var wantFlex = window.FlexSearch ? Promise.resolve(true) : loadScript(FLEX_URL);
    return Promise.all([
      wantFlex,
      fetch("/search-index-" + locale + ".json")
        .then(function (r) { return r.json(); })
        .catch(function () { return null; })
    ]).then(function (pair) {
      docs = Array.isArray(pair[1]) ? pair[1] : [];
      index = buildIndex(docs);
      loaded = true;
      loading = false;
    });
  }

  /* ── querying ─────────────────────────────────────────────────────────── */

  function substringQuery(q) {
    var terms = q.toLowerCase().split(/\s+/).filter(Boolean);
    return docs.filter(function (doc) {
      var hay = [doc.title, doc.description, doc.contentExcerpt].join(" ").toLowerCase();
      return terms.every(function (t) { return hay.indexOf(t) !== -1; });
    });
  }

  function flexQuery(q) {
    var out = [];
    var seen = {};
    var raw = index.search({ query: q, enrich: true, limit: 20 });
    if (!Array.isArray(raw)) return out;
    raw.forEach(function (field) {
      (field.result || []).forEach(function (hit) {
        if (!hit || seen[hit.id]) return;
        seen[hit.id] = true;
        out.push(hit.doc !== undefined ? hit.doc : hit);
      });
    });
    return out;
  }

  function query(q) {
    if (!docs) return [];
    if (!q) return docs.slice(0, 20);
    if (!index) return substringQuery(q);
    try {
      return flexQuery(q);
    } catch (e) {
      return substringQuery(q);
    }
  }

  /* ── rendering ────────────────────────────────────────────────────────── */

  function render(list) {
    rows = list;
    hi = 0;
    results.textContent = "";

    if (list.length === 0) {
      var empty = document.createElement("li");
      empty.className = "tty-search__empty";
      empty.textContent = LABEL.none;
      results.appendChild(empty);
      countEl.textContent = LABEL.none;
      return;
    }

    list.forEach(function (doc, i) {
      var li = document.createElement("li");
      var a = document.createElement("a");
      a.className = "tty-menu__item";
      a.href = doc.url;
      if (i === 0) a.setAttribute("aria-selected", "true");

      var cursor = document.createElement("span");
      cursor.className = "tty-menu__cursor";
      cursor.setAttribute("aria-hidden", "true");
      cursor.textContent = "›";

      var glyph = document.createElement("span");
      glyph.className = "tty-menu__glyph";
      glyph.setAttribute("aria-hidden", "true");
      glyph.textContent = "▸";

      var label = document.createElement("span");
      label.className = "tty-menu__label";
      label.textContent = doc.title;

      a.appendChild(cursor);
      a.appendChild(glyph);
      a.appendChild(label);

      /* Site.jsx puts the date in the row's shortcut slot: the date is what tells
         two posts with similar titles apart. It comes from the build, in the
         index. A document with no date gets no hint and no empty span. */
      if (doc.date) {
        var hint = document.createElement("span");
        hint.className = "tty-menu__hint";
        hint.textContent = doc.date;
        a.appendChild(hint);
      }

      li.appendChild(a);
      results.appendChild(li);
    });

    countEl.textContent = list.length + " " + (list.length === 1 ? LABEL.one : LABEL.many);
  }

  function items() {
    return results.querySelectorAll(".tty-menu__item");
  }

  function move(delta) {
    var all = items();
    if (all.length === 0) return;
    if (all[hi]) all[hi].removeAttribute("aria-selected");
    hi = (hi + delta + all.length) % all.length;
    all[hi].setAttribute("aria-selected", "true");
    all[hi].scrollIntoView({ block: "nearest" });
  }

  function openHighlighted() {
    var all = items();
    if (all[hi]) window.location.assign(all[hi].getAttribute("href"));
  }

  /* ── open and close ───────────────────────────────────────────────────── */

  function isOpen() { return !overlay.hasAttribute("hidden"); }

  /* The lock goes on <html> and <body>. The vendored breakpoints.css sets
     `html, body { overflow-x: hidden }`, so the root element's own overflow drives
     the viewport and `overflow: hidden` on a body of auto height clips nothing.
     The CSS in layout.css must target both selectors. */
  function lock(on) {
    var root = document.documentElement;
    if (on) {
      root.classList.add("tty-search-open");
      document.body.classList.add("tty-search-open");
    } else {
      root.classList.remove("tty-search-open");
      document.body.classList.remove("tty-search-open");
    }
  }

  function open() {
    if (isOpen()) return;
    lastFocus = document.activeElement;
    overlay.removeAttribute("hidden");
    lock(true);
    setExpanded(true);
    input.focus();
    input.select();
    load().then(function () { render(query(input.value.trim())); });
  }

  function close() {
    if (!isOpen()) return;
    overlay.setAttribute("hidden", "");
    lock(false);
    setExpanded(false);
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }

  function setExpanded(on) {
    var openers = document.querySelectorAll("[data-tty-search-open]");
    for (var i = 0; i < openers.length; i++) {
      openers[i].setAttribute("aria-expanded", on ? "true" : "false");
    }
  }

  /* ── wiring ───────────────────────────────────────────────────────────── */

  var openers = document.querySelectorAll("[data-tty-search-open]");
  for (var i = 0; i < openers.length; i++) {
    openers[i].addEventListener("click", function (e) { e.preventDefault(); open(); });
    /* nav.njk ships the control with `hidden`, so no page shows a button that
       cannot do anything. This script is what makes the button work, so this
       script is what reveals it. The Task 5 stub does the same thing, and this
       file overwrites that stub. Drop this line and the nav control stays
       invisible on every page: `/` still opens the overlay, and nothing else
       does. The call is safe when the attribute is absent. */
    openers[i].removeAttribute("hidden");
  }

  var closers = overlay.querySelectorAll("[data-tty-search-close]");
  for (var j = 0; j < closers.length; j++) {
    closers[j].addEventListener("click", close);
  }

  input.addEventListener("input", function () {
    if (timer) clearTimeout(timer);
    timer = setTimeout(function () {
      load().then(function () { render(query(input.value.trim())); });
    }, DEBOUNCE_MS);
  });

  input.addEventListener("keydown", function (e) {
    if (e.key === "ArrowDown") { e.preventDefault(); move(1); }
    else if (e.key === "ArrowUp") { e.preventDefault(); move(-1); }
    else if (e.key === "Enter") { e.preventDefault(); openHighlighted(); }
  });

  /* `/` opens the overlay, but only when the reader is not already typing. */
  function typingInAField(el) {
    if (!el) return false;
    var tag = (el.tagName || "").toLowerCase();
    return tag === "input" || tag === "textarea" || tag === "select" || el.isContentEditable;
  }

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && isOpen()) { e.preventDefault(); close(); return; }
    if (e.key !== "/" || isOpen()) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (typingInAField(document.activeElement)) return;
    e.preventDefault();
    open();
  });
})();
```

One field must come with it. `render()` reads `doc.date`, and the
`searchIndex_${lang}` collection in `.eleventy.js` returns only
`{ id, title, url, description, contentExcerpt }`. Add the date to that map, next to
`contentExcerpt`:

```js
          date: p.data.date
            ? `${p.data.date.getFullYear()}-${leftPadDate(p.data.date.getMonth() + 1)}-${leftPadDate(p.data.date.getDate())}`
            : "",
```

`leftPadDate` is already a module-level helper in `.eleventy.js`, and this is the exact
format the `postDate` filter writes, so a row in the overlay and a row on `/posts/` show the
same string. The date is baked into `/search-index-<locale>.json` at build time — the
overlay never looks a date up at runtime. A post with no date gets no hint.

- [ ] **Step 5: Strip the old search out of the posts page**

In `src/en/posts/index.njk`, delete three regions and keep the post loop:

1. Delete the opening `<div id="blog-search-root" …>` line, the whole
   `<div class="blog-search-in-content">…</div>` block, the whole
   `<div id="blog-search-results" hidden>…</div>` block, and the
   `<div id="blog-posts-list">` opening line.
2. Delete the two matching closing `</div>` lines at the end of the loop.
3. Delete both `<script>` tags at the bottom — the FlexSearch CDN tag and
   `/scripts/search.js`.

The file should be the frontmatter followed by the `{% for post in
collections.postsActive_en %}` loop and nothing else. Task 10 rewrites it whole; this step
only removes the dead search.

Then delete the old script:

```bash
git rm src/scripts/search.js
```

- [ ] **Step 6: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 7: Drive the overlay by hand**

Run: `bun run start` and open `http://localhost:8080/`. Work through all seven:

1. Look at the nav first. The `/ search` control must be visible now. Task 5 ships it with
   `hidden`, and the `openers` loop in Step 4 is what reveals it. If it stays invisible,
   that loop is missing `openers[i].removeAttribute("hidden")`. Click the control: the
   overlay opens. Press `Escape`, then press `/`. The overlay wipes up, bordered yellow,
   with the field focused.
2. Type `kernel`. Rows appear, each with its date right-aligned on the row, and a count in
   the footer.
3. Press `ArrowDown` twice. The highlight moves; the selected row is a yellow bar with
   black text and a visible `›` cursor.
4. Press `Enter`. The browser navigates to that post.
5. Press `/` again, then `Escape`. The overlay closes and focus returns to the key hint
   in the nav.
6. Press `/`, then click the dimmed area outside the panel. It closes.
7. Open the overlay, then scroll with the wheel. The page behind must not move.

Also confirm the lazy load: open the network panel, load a page, and check that
`flexsearch.bundle.js` and `search-index-en.json` are requested only after the first `/`.
Stop the server before you run the check again.

- [ ] **Step 8: Commit**

```bash
git add src/_includes/searchOverlay.njk src/scripts/tty-search.js src/en/posts/index.njk scripts/check-build.sh
git rm --cached src/scripts/search.js 2>/dev/null || true
git commit -m "feat(search): replace the inline search box with a / overlay

The design system search is a keyboard overlay. FlexSearch and the index now
load on first open rather than on every /posts/ visit, and the query falls back
to substring matching if the CDN fails. Arrow keys move the selection, Enter
opens, Escape closes and restores focus, and the page behind cannot scroll.

The in-content input, its result list and scripts/search.js are gone."
```

---
### Task 10: Rebuild the posts landing page

The `Home.jsx` screen on `/posts/`: a hero with the display title, a live terminal demo
that types a command, four recent post rows, every other active post under them, and a
feeds panel. The design system puts a newsletter block in that last slot. There is no
newsletter here, so the slot carries the three real endpoints plus the `/` key hint. Do not
invent a mailing list.

**Order.** Run this task after Task 7, which adds the `postsActive_en` collection and the
`postIndexes` and `readingTime` filters, and after Task 9, which strips the old search out
of this same file. Run it **before** Task 11: Task 11 reads seven `blog.*` strings that
Step 6 adds here.

**One dependency runs the other way, and this task does not fix it.** The hero's primary
button points at `/posts/archive/`, and Task 11 is what creates that page. A reviewer who
accepts Task 10 on its own gets a `Read the archive` button that returns 404 until Task 11
lands. Do not reorder the two tasks to hide it — Task 11 cannot run first, because it needs
these strings. Land Task 11 next, and say so in the commit. Nothing is lost in that window:
the `all posts` block below the hero lists every active post, so every post stays one click
from `/posts/`.

**Files:**
- Create: `src/scripts/tty-typewriter.js`
- Modify: `src/en/posts/index.njk` (full rewrite)
- Modify: `src/styles/tty/layout.css` (append the hero block)
- Modify: `src/_data/i18n/en.json`
- Modify: `.eleventy.js` (add the `plural` filter, beside the Task 7 filters)
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `tty.btn`, `tty.divider`, `tty.panel` (Task 3), `ttyc.postrow`,
  `ttyc.terminal` (Task 4), `.tty-split`, `.tty-screen`, `.tty-section`, `.tty-eyebrow`,
  `.tty-h1--hero`, `.tty-linklist` (Task 5), `postIndexes` and `readingTime` filters
  (Task 7).
- Produces the CSS classes appended to `layout.css`: `.tty-hero__lead`,
  `.tty-hero__actions`.
- Produces `src/scripts/tty-typewriter.js` — reads every `[data-tty-type]` element, takes
  the string from `data-text` and the per-character delay from `data-speed`, and types it
  on a loop. Under `prefers-reduced-motion: reduce` it writes the text once and stops.
- Produces the i18n keys `blog.eyebrow`, `blog.heroLine1`, `blog.heroLine2`,
  `blog.heroLine3`, `blog.lead`, `blog.readArchive`, `blog.latestPost`, `blog.recent`,
  `blog.allPosts`, `blog.feeds`, `blog.feedsHint`, `blog.searchHint`, and the counted pair
  `blog.count` (plural) / `blog.post` (singular).
- Produces the `plural` filter in `.eleventy.js`. Every counted label in Tasks 11, 12 and 13
  must go through it.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "posts landing page"
have "scripts/tty-typewriter.js"
grep_in "posts/index.html" 'class="tty-h1 tty-h1--hero"' "the hero title is present"
grep_in "posts/index.html" 'class="tty-eyebrow"' "the eyebrow is present"
grep_in "posts/index.html" 'class="tty-term"' "the terminal demo is present"
grep_in "posts/index.html" 'data-tty-type' "the typewriter target is present"
grep_in "posts/index.html" '/scripts/tty-typewriter.js' "the typewriter script is loaded"
grep_in "posts/index.html" 'class="tty-postrow"' "post rows use the design system row"
grep_in "posts/index.html" '/posts/archive/' "the archive is linked from the hero"
grep_in "posts/index.html" 'class="tty-panel__title"' "the feeds panel is present"
grep_in "posts/index.html" "3 endpoints" "the feeds panel counts only its endpoints"
grep_not "posts/index.html" '<h2 class="blog">' "the old Pico post headings are gone"
count_at_least "posts/index.html" 'class="tty-term__path"' 3 "the terminal lists three recent slugs"
count_at_least "posts/index.html" 'class="tty-postrow"' 13 "every active post is listed (13 today)"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `file scripts/tty-typewriter.js is missing` plus twelve more.

- [ ] **Step 3: Append the hero CSS**

Append to `src/styles/tty/layout.css`:

```css
/* ── Hero (ui_kits/blog/Home.jsx) ───────────────────────────────────────── */
.tty-hero__lead {
  max-width: 52ch;
  margin: 22px 0 0;
  font-size: var(--text-md);
  line-height: 1.8;
  color: var(--text-muted);
  text-wrap: pretty;
}
.tty-hero__actions {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-top: 26px;
}
.tty-hero__title { margin: 18px 0 0; }
```

- [ ] **Step 4: Write the typewriter script**

Create `src/scripts/tty-typewriter.js`:

```js
/* Typewriter for the terminal demo on /posts/.
   Reads data-text and data-speed off each [data-tty-type] element and types the
   string on a loop, holding the finished line before it restarts.

   Under prefers-reduced-motion the text is written once and the timer never
   starts — the design system collapses every duration in that case, and a loop
   with no duration would flicker. */
(function () {
  var nodes = document.querySelectorAll("[data-tty-type]");
  if (nodes.length === 0) return;

  var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  for (var i = 0; i < nodes.length; i++) {
    run(nodes[i]);
  }

  function run(el) {
    var text = el.getAttribute("data-text") || "";
    if (!text) return;

    if (still) {
      el.textContent = text;
      return;
    }

    var speed = parseInt(el.getAttribute("data-speed"), 10) || 55;
    var HOLD_MS = 2400;
    var n = 0;

    el.textContent = "";

    function step() {
      n += 1;
      el.textContent = text.slice(0, n);
      if (n < text.length) {
        window.setTimeout(step, speed);
        return;
      }
      window.setTimeout(function () {
        n = 0;
        el.textContent = "";
        window.setTimeout(step, speed);
      }, HOLD_MS);
    }

    window.setTimeout(step, speed);
  }
})();
```

- [ ] **Step 5: Rewrite the posts landing page**

Replace the whole of `src/en/posts/index.njk` with:

```njk
---
layout: layouts/layout.njk
type: blog
title: Posts
description: Thoughts on software engineering, tools, languages, and technology.
---
{% import "tty/core.njk" as tty %}
{% import "tty/content.njk" as ttyc %}
{%- set posts = collections.postsActive_en -%}
{%- set idx = posts | postIndexes -%}
<div class="tty-screen">

  <section class="tty-split">
    <div>
      <p class="tty-eyebrow">{{ i18n.en.blog.eyebrow }}</p>
      <h1 class="tty-h1 tty-h1--hero tty-hero__title">
        {{ i18n.en.blog.heroLine1 }}<br>
        {{ i18n.en.blog.heroLine2 }}<br>
        <span class="tty-accent">{{ i18n.en.blog.heroLine3 }}</span>
      </h1>
      <p class="tty-hero__lead">{{ i18n.en.blog.lead }}</p>
      <div class="tty-hero__actions">
        {{ tty.btn(i18n.en.blog.readArchive, "/posts/archive/", "primary") }}
        {{ tty.btn(i18n.en.blog.latestPost, posts[0].url) }}
      </div>
    </div>

    {% call ttyc.terminal("~/posts") %}
      <div class="tty-term__line">
        <span class="tty-term__prompt" aria-hidden="true">$</span>
        <span data-tty-type data-text="ellian posts --recent 3" data-speed="55">ellian posts --recent 3</span>
      </div>
      <div class="tty-term__out" style="margin-top: 10px">
        {%- for post in posts.slice(0, 3) -%}
        <div class="tty-term__line">
          <span class="tty-term__date">{{ post.date | postDate }}</span>
          <span class="tty-term__path">{{ post.fileSlug }}</span>
        </div>
        {%- endfor -%}
      </div>
    {% endcall %}
  </section>

  <section>
    {{ tty.divider(i18n.en.blog.recent) }}
    <div style="margin-top: 14px">
      {%- for post in posts.slice(0, 4) -%}
        {{ ttyc.postrow(post, idx[post.url]) }}
      {%- endfor -%}
    </div>
  </section>

  {% if posts.length > 4 %}
  <section>
    {{ tty.divider(i18n.en.blog.allPosts) }}
    <div style="margin-top: 14px">
      {%- for post in posts.slice(4) -%}
        {{ ttyc.postrow(post, idx[post.url]) }}
      {%- endfor -%}
    </div>
  </section>
  {% endif %}

  {% call tty.panel(i18n.en.blog.feeds, i18n.en.blog.feedsHint) %}
    <div class="tty-linklist">
      <div class="tty-linklist__row">
        <span class="tty-linklist__key">atom</span>
        <a href="/feed.xml">/feed.xml</a>
      </div>
      <div class="tty-linklist__row">
        <span class="tty-linklist__key">llms</span>
        <a href="/llms.txt">/llms.txt</a>
      </div>
      <div class="tty-linklist__row">
        <span class="tty-linklist__key">index</span>
        <a href="/sitemap.xml">/sitemap.xml</a>
      </div>
      <div class="tty-linklist__row">
        <span class="tty-linklist__key">search</span>
        <span>{{ i18n.en.blog.searchHint }}</span>
      </div>
    </div>
  {% endcall %}

</div>
<script defer src="/scripts/tty-typewriter.js"></script>
```

Four notes on this template:

- **Never write `posts | slice(...)` here.** The Nunjucks `slice` *filter* cuts a list into
  N chunks, so `posts | slice(0, 3)` asks for zero chunks and returns an empty list. It does
  not throw: the build stays green and the terminal ships as an empty box. Use the member
  form, `posts.slice(0, 3)`. Nunjucks resolves it through `runtime.memberLookup`, which
  binds and calls any function-valued property, so it reaches `Array.prototype.slice`.
  Verified against nunjucks 3.2.4: `{% for x in a | slice(0,3) %}` over a five-item list
  renders nothing, `{% for x in a.slice(0,3) %}` renders three items.
- **The page lists every active post, not four.** The `recent` block is the design system's
  Home screen; the `all posts` block below it keeps the other nine posts linked from
  `/posts/`, as they are today. The archive page adds the archived post and the year
  grouping on top of that; it does not replace this list.
- The typewriter target carries its text **twice**: once in `data-text`, and once as
  element content. The content is what a reader without JavaScript sees; the script clears
  it before it starts typing. Keep both in step.
- `{% call %}` is how the `panel` and `terminal` macros take their body. That is why they
  are `{% macro %}` with `caller()` and not plain includes.

- [ ] **Step 6: Register the plural filter**

This task writes no i18n string. Task 5 Step 7 owns `src/_data/i18n/en.json` and already
lands every `blog.*` key this page reads. Do not edit that file here — two tasks replacing
the same JSON object is how `blog.readPosts` gets silently dropped.

What this task does add is one filter. `blog.count` is the plural word and `blog.post` is
the singular. Nine tags carry exactly one post, and `1 posts` is wrong. Do not pick the word
in a template by hand. Add this to `.eleventy.js`, beside the filters Task 7 registers:

```js
  /* "1 post", "13 posts". The design system counts exactly: Site.jsx writes
     `result{results.length === 1 ? "" : "s"}`, and tty-search.js does the same. */
  eleventyConfig.addFilter("plural", (count, one, many) => {
    return `${count} ${count === 1 ? one : many}`;
  });
```

The filter prints the number **and** the word, so a call site must not print the count
again. The whole label is:

```njk
{{ posts.length | plural(i18n.en.blog.post, i18n.en.blog.count) }}
```

which renders `1 post` or `13 posts`. Writing `{{ posts.length }} {{ posts.length | plural(…) }}`
renders `13 13 posts`. Tasks 11, 12 and 13 hold every other counted label on the site, so
each of them calls this filter the same way.

- [ ] **Step 7: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

If either `count_at_least` counts fewer rows than it asks for, a loop still uses the `slice`
filter instead of the `posts.slice(...)` member form. Read the first note in Step 5 and run
again. If `3 endpoints` fails, Step 6's JSON still says `4 endpoints`.

- [ ] **Step 8: Look at the landing page**

Run: `bun run start` and open `http://localhost:8080/posts/`.
Expect: the display title over three lines with `AND THE TOOLS` in yellow, two buttons, a
bordered terminal on the right that retypes `ellian posts --recent 3` on a loop with three
dated slugs under it, four numbered post rows under `recent` that turn yellow on hover and
grow a left rule, the other nine active posts under `all posts`, and the feeds panel with
`3 endpoints` beside its title. Count the rows and the slugs: thirteen rows, three slugs. An
empty terminal body means a loop still uses the `slice` filter. On a phone the two columns
stack and the terminal drops below the hero.

The `Read the archive` button returns 404 until Task 11 lands. That is expected here, and it
is why Task 11 must be the next commit.

Check the reduced-motion path too: in Firefox set `ui.prefersReducedMotion` to `1`, or in
Chrome use the rendering panel's `prefers-reduced-motion` emulation. The command must show
in full and never retype.
Stop the server before you run the check again.

- [ ] **Step 9: Commit**

```bash
git add src/scripts/tty-typewriter.js src/en/posts/index.njk src/styles/tty/layout.css src/_data/i18n/en.json scripts/check-build.sh
git commit -m "feat(blog): rebuild the posts landing page on the design system

The Home screen: display hero, a terminal that types 'ellian posts --recent 3'
on a loop, four numbered post rows under 'recent', every other active post under
'all posts', and a feeds panel. The design system puts a newsletter in that last
slot; there is no newsletter here, so the panel lists three endpoints - the atom
feed, llms.txt and the sitemap - plus the / search hint, and its subtitle counts
the three endpoints only.

The typewriter writes its line once and stops under prefers-reduced-motion.

The hero links /posts/archive/, which the next commit creates. That button
returns 404 until then."
```

---
### Task 11: Build the archive view

`/posts/archive/` is the `Archive.jsx` screen and the one page that lists **every** post,
archived included. Rows are numbered and grouped by year. A tag rail and a by-year rail sit
beside the list on desktop and fold into a `<details>` under 1280px. A two-button toggle
flips the sort order.

Two things are resolved at build time on purpose:

- **Tag filtering is a link, not a script.** The rail links to the `/posts/tag/<slug>/`
  pages Eleventy already generates. Those pages are crawlable and they already work. A
  client-side filter would duplicate that machinery for nothing.
- **Sorting is CSS.** `flex-direction: column-reverse` on the year list and on each year's
  rows flips the whole page from one class on the root. No rows are re-ordered in
  JavaScript, so nothing can drift out of step with the index numbers.

One deviation from `Archive.jsx`, on top of the ones Task 3 lists: the sort control is a
two-button `.tty-tabs` tablist, not the `Select` the screen uses. A `<select>` needs
JavaScript behind it to do anything, and the two buttons carry `aria-selected`, so the
state reaches a screen reader.

**Files:**
- Create: `src/en/posts/archive.njk`
- Create: `src/scripts/tty-archive.js`
- Modify: `src/styles/tty/layout.css` (append the archive block)
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `tty.divider`, `tty.tag` (Task 3), `ttyc.postrow`, `ttyc.foldout` (Task 4),
  `.tty-split--rail`, `.tty-rail`, `.tty-rail--sticky`, `.tty-when-desktop`, `.tty-when-compact`,
  `.tty-tabs`, `.tty-menu` (Tasks 3 and 5), `groupByYear` and `postIndexes` filters
  (Task 7), the `filterByTag` filter (`.eleventy.js:244`), the `tagSlug` filter
  (`.eleventy.js:116`), and the `posts_en` and `tags_en` collections
  (`.eleventy.js:158`, `:189`).
- Consumes the `plural(count, singular, pluralForm)` filter from Task 10, and the i18n keys
  `blog.post` and `blog.count`. Task 10 Step 6 must write `"post": "post"` beside
  `"count": "posts"` in the `blog` object. Without the singular key a count of one renders
  the number and no noun.
- Produces the URL `/posts/archive/`. The global `permalink` function in
  `.eleventy.js:284` turns the file path `src/en/posts/archive.njk` into
  `/posts/archive/index.html` with no extra configuration.
- Produces the CSS classes appended to `layout.css`: `.tty-archive`,
  `.tty-archive--oldest`, `.tty-archive__head`, `.tty-archive__count`,
  `.tty-archive__years`, `.tty-archive__year`, `.tty-archive__rows`.
- Produces one density override for the rail: under 1280px,
  `.tty-archive .tty-menu--dense .tty-menu__item` takes back `var(--row-h)`.
  `Archive.jsx` passes `dense={!bp.compact}`, so dense is a desktop density only.
- Produces `src/scripts/tty-archive.js` — reads `[data-tty-sort]` buttons inside
  `#tty-archive` and toggles `.tty-archive--oldest` on that root.
- Produces a local `{% macro rail() %}` inside `archive.njk`. It renders once and is
  called twice — from the desktop `<aside>` and from the compact `<details>` — so the two
  layouts cannot drift.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "archive view"
have "posts/archive/index.html"
have "scripts/tty-archive.js"
grep_in "posts/archive/index.html" 'id="tty-archive"' "the archive root is present"
grep_in "posts/archive/index.html" "Tools I use 2024" "the archive lists the archived post"
grep_in "posts/archive/index.html" "Tools I&#39;ve been using - 2025" "the archive lists the active posts"
grep_in "posts/archive/index.html" 'class="tty-badge tty-badge--outline tty-badge--warn"' "the archived row is badged"
grep_in "posts/archive/index.html" 'data-tty-sort="oldest"' "the sort toggle is present"
grep_in "posts/archive/index.html" 'id="y-2026"' "the year sections are anchored"
grep_in "posts/archive/index.html" 'href="#y-2026"' "the by-year rail links to a year"
grep_in "posts/archive/index.html" '/posts/tag/linux/' "the tag rail links to a tag page"
grep_in "posts/archive/index.html" '<details class="tty-foldout">' "the compact filter foldout is present"
grep_in "posts/archive/index.html" 'class="tty-rail--sticky tty-when-desktop"' "the desktop rail is present"
grep_in "posts/archive/index.html" '/scripts/tty-archive.js' "the sort script is loaded"
count_at_least "posts/archive/index.html" 'class="tty-postrow"' 14 "every post appears in the archive"
grep_in "styles/tty/layout.css" ".tty-archive--oldest" "the sort flip CSS is present"
grep_in "styles/tty/layout.css" "scroll-margin-top: calc(52px + var(--sp-4))" "the year anchors clear the sticky nav"
grep_in "styles/tty/layout.css" ".tty-archive .tty-menu--dense .tty-menu__item" "the compact rail keeps the full row height"
```

Three notes on these assertions:

- The title assertion greps `Tools I&#39;ve been using - 2025`, with the escaped
  apostrophe. Nunjucks escapes `'` to `&#39;` when it prints `{{ post.data.title }}`, and
  `grep -qF` compares bytes, so the straight apostrophe can never match the built HTML.
- The `14` is the current post count. If a post is added later the assertion still holds,
  because it is a floor, not an equality.
- `/posts/` linking the archive is Task 10's assertion, not this one. Task 11 must not test
  a page Task 10 writes, or neither task can go green on its own.

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `file posts/archive/index.html is missing` plus sixteen more.

- [ ] **Step 3: Append the archive CSS**

Append to `src/styles/tty/layout.css`:

```css
/* ── Archive screen (ui_kits/blog/Archive.jsx) ──────────────────────────── */
.tty-archive__head {
  display: flex;
  align-items: center;
  gap: 14px;
  flex-wrap: wrap;
  margin-bottom: var(--sp-6);
}
.tty-archive__count { font-size: var(--text-xs); color: var(--text-faint); }
.tty-archive__head .tty-tabs { border-bottom: 0; }

.tty-archive__years { display: flex; flex-direction: column; gap: var(--sp-8); }
/* The by-year rail jumps to these sections, so a year heading must clear the
   52px sticky nav. Same arithmetic as the prose headings in prose.css — keep the
   two in step. */
.tty-archive__year {
  display: flex;
  flex-direction: column;
  scroll-margin-top: calc(52px + var(--sp-4));
}
.tty-archive__year .tty-divider { margin-bottom: 12px; }
.tty-archive__rows { display: flex; flex-direction: column; }

/* Dense is a desktop density: Archive.jsx passes dense={!bp.compact}. The rail
   macro renders one class for both layouts, so the compact row height is
   corrected here instead of with a template branch. var(--row-h) is 44px on
   touch and 32px for a fine pointer, which is what the component does. */
@media (max-width: 1279.98px) {
  .tty-archive .tty-menu--dense .tty-menu__item { min-height: var(--row-h); }
}

/* Oldest-first is a layout flip, not a re-sort: both the year list and the rows
   inside each year reverse from one class on the root. The index numbers stay
   attached to their post, so 001 sits at the top when oldest is chosen. */
.tty-archive--oldest .tty-archive__years,
.tty-archive--oldest .tty-archive__rows { flex-direction: column-reverse; }
```

- [ ] **Step 4: Write the sort script**

Create `src/scripts/tty-archive.js`:

```js
/* Archive sort toggle. Flips one class on #tty-archive; the CSS reverses both
   the year list and the rows inside each year. No rows move in the DOM, so the
   index numbers cannot drift out of step with their posts.

   The choice is not persisted. The order is visible in one glance, so a stored
   preference would only surprise the reader on the next visit. */
(function () {
  var root = document.getElementById("tty-archive");
  if (!root) return;

  var buttons = root.querySelectorAll("[data-tty-sort]");
  if (buttons.length === 0) return;

  function apply(order) {
    if (order === "oldest") root.classList.add("tty-archive--oldest");
    else root.classList.remove("tty-archive--oldest");
    for (var i = 0; i < buttons.length; i++) {
      var on = buttons[i].getAttribute("data-tty-sort") === order;
      buttons[i].setAttribute("aria-selected", on ? "true" : "false");
    }
  }

  for (var i = 0; i < buttons.length; i++) {
    buttons[i].addEventListener("click", function () {
      apply(this.getAttribute("data-tty-sort"));
    });
  }
})();
```

- [ ] **Step 5: Write the archive page**

Create `src/en/posts/archive.njk`:

```njk
---
layout: layouts/layout.njk
type: blog
title: Archive
description: Every post on this site, newest first, grouped by year and filterable by tag.
---
{% import "tty/core.njk" as tty %}
{% import "tty/content.njk" as ttyc %}
{#
  The archive is the one page that lists every post, archived included. /posts/
  shows the active ones; this is the whole record.
#}
{%- set posts = collections.posts_en -%}
{%- set tags = collections.tags_en -%}
{%- set idx = posts | postIndexes -%}
{%- set groups = posts | groupByYear -%}

{% macro rail() %}
<div class="tty-rail">
  <div>
    {{ tty.divider(i18n.en.blog.tags) }}
    <div style="display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px">
      {%- for tag in tags -%}
        {{ tty.tag(tag, "/posts/tag/" + (tag | tagSlug) + "/", (posts | filterByTag(tag)).length) }}
      {%- endfor -%}
    </div>
  </div>
  <div>
    {{ tty.divider(i18n.en.blog.byYear) }}
    <ul class="tty-menu tty-menu--dense" style="margin-top: 10px">
      {%- for group in groups -%}
      <li>
        <a class="tty-menu__item" href="#y-{{ group.year }}">
          <span class="tty-menu__cursor" aria-hidden="true">›</span>
          <span class="tty-menu__label">{{ group.year }}</span>
          <span class="tty-menu__hint">{{ group.posts.length }}</span>
        </a>
      </li>
      {%- endfor -%}
    </ul>
  </div>
</div>
{% endmacro %}

<div class="tty-archive" id="tty-archive">
  <div class="tty-split tty-split--rail">
    <div>
      <div class="tty-archive__head">
        <h1 class="tty-h1">{{ i18n.en.blog.archive }}</h1>
        <span class="tty-archive__count">{{ posts.length | plural(i18n.en.blog.post, i18n.en.blog.count) }}</span>
        <span class="tty-spacer"></span>
        <div class="tty-tabs" role="tablist" aria-label="{{ i18n.en.blog.archive }}">
          <button class="tty-tabs__tab" type="button" role="tab"
                  data-tty-sort="newest" aria-selected="true">{{ i18n.en.blog.sortNewest }}</button>
          <button class="tty-tabs__tab" type="button" role="tab"
                  data-tty-sort="oldest" aria-selected="false">{{ i18n.en.blog.sortOldest }}</button>
        </div>
      </div>

      <div class="tty-when-compact">
        {% call ttyc.foldout(i18n.en.blog.filter, tags.length + " " + i18n.en.blog.tags) %}
          {{ rail() }}
        {% endcall %}
      </div>

      <div class="tty-archive__years">
        {%- for group in groups -%}
        <section class="tty-archive__year" id="y-{{ group.year }}">
          {{ tty.divider(group.year) }}
          <div class="tty-archive__rows">
            {%- for post in group.posts -%}
              {{ ttyc.postrow(post, idx[post.url], post.data.archived) }}
            {%- endfor -%}
          </div>
        </section>
        {%- endfor -%}
      </div>
    </div>

    <aside class="tty-rail--sticky tty-when-desktop">
      {{ rail() }}
    </aside>
  </div>
</div>
<script defer src="/scripts/tty-archive.js"></script>
```

Two notes:

- `rail()` is called twice and the CSS shows one. `.tty-when-compact` and
  `.tty-when-desktop` never both render, so no reader sees the rail twice, and the two
  layouts cannot drift because there is one source.
- The year anchor is `#y-2026`, not `#2026`. An `id` that starts with a digit is legal in
  HTML5 but is not a valid CSS identifier, so a bare `#2026` selector would break any future
  rule. The `y-` prefix avoids it.

- [ ] **Step 6: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 7: Drive the archive by hand**

Run: `bun run start` and open `http://localhost:8080/posts/archive/`.

1. Count the rows. Every post must appear, including `Tools I use 2024`, which carries an
   `ARCHIVED` badge in its meta column.
2. Rows are numbered `014` down to `001`, newest first.
3. Click `oldest first`. The years reverse, the rows inside each year reverse, `001` moves
   to the top, and the two buttons swap their yellow underline.
4. Click a year in the rail. The page jumps to that year's heading, clear of the sticky nav.
5. Click a tag in the rail. It navigates to `/posts/tag/<slug>/`.
6. Narrow the window below 1280px. The rail disappears and a `▸ FILTER` foldout appears
   under the title. Open it: the same tag cloud and year list are inside, with a `▾` marker.
   Measure one year row: it is 44px tall on a touch screen, not the 40px dense row. Dense
   is a desktop density, which is what `Archive.jsx` does with `dense={!bp.compact}`.

Stop the server before you run the check again.

- [ ] **Step 8: Commit**

```bash
git add src/en/posts/archive.njk src/scripts/tty-archive.js src/styles/tty/layout.css scripts/check-build.sh
git commit -m "feat(blog): add the archive view at /posts/archive/

Every post, archived included, as a numbered row grouped by year, with an
ARCHIVED badge on the ones /posts/ hides. The tag rail links to the tag pages
Eleventy already generates rather than filtering in the browser, and the sort
toggle is a CSS flip rather than a re-sort, so the index numbers cannot drift.

The rail renders from one macro and CSS picks the desktop aside or the compact
<details>, so the two layouts stay in step."
```

---
### Task 12: Restyle the tag pages

`/posts/tag/<slug>/` is where the archive rail sends the reader, so it has to look like the
archive. It reuses the same row macro and the same head. Like the archive, it lists archived
posts too and badges them — a tag page is a record, not a reading list.

**Files:**
- Modify: `src/tag/index.njk` (full rewrite of the body; frontmatter keeps its pagination)
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `tty.divider`, `tty.tag` (Task 3), `ttyc.postrow` (Task 4), `.tty-archive*`
  (Task 11), `postIndexes` (Task 7), `filterByTag` (`.eleventy.js:244`).
- Consumes the `plural(count, singular, pluralForm)` filter from Task 10, and the i18n keys
  `blog.post` and `blog.count`. Ten of the twenty tags carry exactly one post, so the
  singular key is load-bearing here: Task 10 Step 6 must write `"post": "post"` beside
  `"count": "posts"` in the `blog` object. The Step 1 assertion on `/posts/tag/japanese/`
  fails if it is missing.
- Produces no new class, no new filter. The `tagPage`, `permalink` and `locale` computed
  data in `src/tag/tag.11tydata.js` is untouched, so every tag URL is unchanged.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "tag pages"
have "posts/tag/linux/index.html"
grep_in "posts/tag/linux/index.html" 'class="tty-postrow"' "tag pages use the design system row"
grep_in "posts/tag/linux/index.html" 'class="tty-archive__head"' "tag pages reuse the archive head"
grep_in "posts/tag/linux/index.html" "/posts/archive/" "a tag page links back to the archive"
grep_in "posts/tag/japanese/index.html" '>1 post</span>' "a one-post tag page counts in the singular"
grep_not "posts/tag/linux/index.html" 'class="tag-pill"' "the old tag pills are gone"
grep_not "posts/tag/linux/index.html" '<h2 class="blog">' "the old Pico headings are gone"
```

`japanese` is the tag the singular assertion uses. It carries one post, and so do nine
other tags, so the plural noun must come from the `plural` filter and not from one fixed
string.

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `tag pages use the design system row` and five more. The `have` assertion
passes, because the tag pages already exist today.

- [ ] **Step 3: Rewrite the tag page**

Replace the whole of `src/tag/index.njk` with:

```njk
---
layout: layouts/layout.njk
type: blog
pagination:
  data: collections.tagPages
  size: 1
  alias: tagPage
---
{% import "tty/core.njk" as tty %}
{% import "tty/content.njk" as ttyc %}
{#
  One page per (language, tag) pair. `tagPage`, `permalink` and `locale` are
  computed in src/tag/tag.11tydata.js — do not set them here.

  Like /posts/archive/, this lists archived posts too and badges them. A tag page
  is a record of what carries the tag, not a reading list.
#}
{%- set posts = collections['posts_' + tagPage.lang] | filterByTag(tagPage.tag) -%}
{%- set idx = posts | postIndexes -%}
<div class="tty-archive">
  <div class="tty-archive__head">
    <h1 class="tty-h1">{{ i18n[locale].blog.postsTagged }} {{ tagPage.tag }}</h1>
    <span class="tty-archive__count">{{ posts.length | plural(i18n[locale].blog.post, i18n[locale].blog.count) }}</span>
    <span class="tty-spacer"></span>
    <a class="tty-btn tty-btn--sm" href="{{ '/posts/archive' | i18nUrl(locale) }}/">{{ i18n[locale].blog.archive }}</a>
  </div>

  {% if posts.length == 0 %}
  <p class="tty-search__empty">{{ i18n[locale].blog.noPostsWithTag }}</p>
  {% else %}
  <div class="tty-archive__rows">
    {%- for post in posts -%}
      {{ ttyc.postrow(post, idx[post.url], post.data.archived) }}
    {%- endfor -%}
  </div>
  {% endif %}
</div>
```

`.tty-search__empty` is reused for the empty state — it is the one "nothing here" style in
the system, and duplicating it under a second name would be the wrong kind of tidy.

- [ ] **Step 4: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 5: Look at three tag pages**

Run: `bun run start`. Open `http://localhost:8080/posts/tag/linux/`,
`http://localhost:8080/posts/tag/tools/` and `http://localhost:8080/posts/tag/japanese/`.
Expect: the same head and rows as the archive, a small `ARCHIVE` button on the right, and
numbered rows. Confirm `tools` shows the archived 2024 post with its badge. Confirm
`japanese` counts `1 post`, in the singular.
Stop the server before you run the check again.

- [ ] **Step 6: Commit**

```bash
git add src/tag/index.njk scripts/check-build.sh
git commit -m "feat(blog): restyle the tag pages on the design system

A tag page is where the archive rail sends the reader, so it now reuses the
archive head and the same numbered rows, archived posts badged. Every tag URL
is unchanged — the computed permalink data was not touched."
```

---

### Task 13: Add the preprints page

`/preprints/` lists the papers. One row per paper: title, venue, date. The row opens the
PDF in a new tab. No detail page, no generated BibTeX — that is what the owner asked for.

The PDFs already live in `preprints/` at the repository root, outside `src/`, and Eleventy
does not copy them today. This task adds the passthrough.

**The paper metadata is real, read out of the PDF — do not paraphrase it.** The title and
the five authors below come from the first page of
`Corporate_Truck_Factor__Firm_Level_Knowledge_Concentration_in_Linux_Kernel_Subsystems.pdf`.
The PDF carries no venue line, so `venue` is `"preprint"`. **Ask the owner** whether a
venue or a submission status should replace that, and whether a DOI or arXiv identifier
exists. Do not invent one.

**Files:**
- Create: `src/_data/preprints.js`
- Create: `src/en/preprints.njk`
- Modify: `.eleventy.js` (two edits: one passthrough copy, next to the others around line
  104, and the `pad3` filter beside the Task 7 filters)
- Modify: `src/styles/tty/layout.css` (append the paper row block)
- Modify: `src/_data/i18n/en.json`
- Modify: `src/llms.njk`
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `tty.divider` (Task 3), `.tty-archive__head`, `.tty-h1`, `.tty-prose` (Tasks 4,
  5, 11).
- Consumes the `plural(count, singular, pluralForm)` filter from Task 10. The page ships
  with one paper, so the singular form is what a reader sees on day one.
- Produces the global data array `preprints`, available to templates as `preprints`. Each
  entry has exactly these keys, all strings: `title`, `authors`, `venue`, `date`
  (`YYYY-MM-DD`), `pdf` (a site-absolute URL). Newest first — the template does not sort.
- Produces the filter `pad3(n) -> string` — a zero-padded three-digit number. Step 6
  registers it in `.eleventy.js`, beside the Task 7 filters.
- Produces the CSS classes appended to `layout.css`: `.tty-paper`, `.tty-paper__index`,
  `.tty-paper__body`, `.tty-paper__title`, `.tty-paper__authors`, `.tty-paper__meta`,
  `.tty-paper__ext`.
- Produces the URL `/preprints/`, already linked from the nav by Task 5.
- Produces the i18n keys `preprints.title`, `preprints.description`, `preprints.paper`,
  `preprints.papers`, `preprints.openHint`.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "preprints"
have "preprints/index.html"
have "preprints/Corporate_Truck_Factor__Firm_Level_Knowledge_Concentration_in_Linux_Kernel_Subsystems.pdf"
grep_in "preprints/index.html" "Corporate Truck Factor" "the paper title is listed"
grep_in "preprints/index.html" "Paulo Meirelles" "the author list is listed"
grep_in "preprints/index.html" 'target="_blank"' "the row opens in a new tab"
grep_in "preprints/index.html" 'rel="noreferrer noopener"' "the new tab is opened safely"
grep_in "preprints/index.html" ".pdf" "the row links a PDF"
grep_in "preprints/index.html" 'class="tty-paper"' "the paper row renders"
grep_in "preprints/index.html" '>1 paper</span>' "the count reads the singular"
grep_in "preprints/index.html" 'aria-current="page"' "the preprints tab is marked active"
grep_in "llms.txt" "/preprints/" "llms.txt points at the preprints page"
grep_in "styles/tty/layout.css" ".tty-paper__title" "the paper row CSS is present"
```

The nav link is not tested here. Task 5 builds the tab strip, so a grep for `/preprints/`
in `index.html` passes from Task 5 on and proves nothing at this point. `class="tty-paper"`
tests the row this task writes instead.

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `file preprints/index.html is missing` plus eleven more.

- [ ] **Step 3: Copy the PDFs into the build**

In `.eleventy.js`, next to the other passthrough calls (after the `public` copy on line
104), add:

```js
  // Papers live in preprints/ at the repository root, outside src/, because they
  // are release artefacts rather than site sources. Copy them verbatim; the page
  // that lists them is generated from src/_data/preprints.js.
  eleventyConfig.addPassthroughCopy("preprints");
```

`dist/preprints/` then holds both the copied PDFs and the generated `index.html`. The two
never collide, because no PDF is named `index.html`.

- [ ] **Step 4: Write the paper data**

Create `src/_data/preprints.js`:

```js
/**
 * Papers listed at /preprints/. Newest first — the template does not sort.
 *
 * Every field is a string:
 *   title    the paper title, as printed on the PDF
 *   authors  the full author list, in the printed order, separated by ", "
 *   venue    where it stands: a conference or journal name, or "preprint"
 *   date     YYYY-MM-DD
 *   pdf      site-absolute URL under /preprints/, matching a file in the
 *            repository-root preprints/ directory
 *
 * Adding a paper is two steps: drop the PDF in preprints/ and add an entry here.
 */
module.exports = [
  {
    title:
      "Corporate Truck Factor: Firm-Level Knowledge Concentration in Linux Kernel Subsystems",
    authors:
      "Ellian Carlos Costa, Gabriel Braga Lagrotaria, Ricardo Hideki Hangai Kojo, Arthur Pilone, Paulo Meirelles",
    venue: "preprint",
    date: "2026-09-21",
    pdf: "/preprints/Corporate_Truck_Factor__Firm_Level_Knowledge_Concentration_in_Linux_Kernel_Subsystems.pdf",
  },
];
```

- [ ] **Step 5: Append the paper row CSS**

Append to `src/styles/tty/layout.css`:

```css
/* ── Paper row (/preprints/) ─────────────────────────────────────────────── */
/* The same shape as .tty-postrow, but the meta column carries a venue and the
   row leaves the site, so it ends in an outbound marker. */
.tty-paper {
  display: flex;
  gap: 18px;
  padding: 14px;
  color: inherit;
  background: transparent;
  text-decoration: none;
  border: 0;
  border-top: var(--border-w) solid var(--border-faint);
  border-left: var(--border-w-thick) solid transparent;
  transition: background var(--dur-fast) var(--ease-out),
              border-color var(--dur-fast) var(--ease-out);
}
.tty-paper:hover { background: var(--surface-raised); border-left-color: var(--yellow); }
.tty-paper__index {
  flex: none;
  width: 34px;
  font-family: var(--font-display);
  font-size: var(--text-sm);
  color: var(--text-faint);
  -webkit-font-smoothing: none;
  font-smooth: never;
  transition: color var(--dur-fast) var(--ease-out);
}
.tty-paper:hover .tty-paper__index { color: var(--yellow); }
.tty-paper__body { flex: 1; min-width: 0; }
.tty-paper__title {
  margin: 0;
  font-family: var(--font-display);
  font-size: 17px;
  line-height: var(--leading-tight);
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--text-primary);
  -webkit-font-smoothing: none;
  font-smooth: never;
  transition: color var(--dur-fast) var(--ease-out);
}
.tty-paper:hover .tty-paper__title { color: var(--yellow); }
.tty-paper__authors {
  margin: 7px 0 0;
  font-size: var(--text-sm);
  line-height: 1.6;
  color: var(--text-muted);
  text-wrap: pretty;
}
.tty-paper__meta {
  flex: none;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
  font-size: var(--text-xs);
  color: var(--text-faint);
  white-space: nowrap;
}
.tty-paper__ext { font-family: var(--font-glyph); }

@media (max-width: 430px) {
  .tty-paper { flex-wrap: wrap; gap: 10px; }
  .tty-paper__meta {
    flex-direction: row;
    align-items: center;
    gap: 10px;
    width: 100%;
    padding-left: 34px;
  }
}
```

- [ ] **Step 6: Write the preprints page**

Create `src/en/preprints.njk`:

```njk
---
layout: layouts/layout.njk
title: Preprints
description: Papers and preprints on open source development, knowledge concentration, and the Linux kernel.
---
{% import "tty/core.njk" as tty %}
{#
  One row per paper, straight to the PDF in a new tab. The list comes from
  src/_data/preprints.js; the PDFs are copied from the repository-root
  preprints/ directory by a passthrough in .eleventy.js.
#}
<div class="tty-screen">
  <section>
    <div class="tty-archive__head">
      <h1 class="tty-h1">{{ i18n.en.preprints.title }}</h1>
      <span class="tty-archive__count">{{ preprints.length | plural(i18n.en.preprints.paper, i18n.en.preprints.papers) }}</span>
      <span class="tty-spacer"></span>
      <span class="tty-archive__count">{{ i18n.en.preprints.openHint }}</span>
    </div>

    <p class="tty-prose tty-prose--md">{{ i18n.en.preprints.description }}</p>

    <div style="margin-top: var(--sp-6)">
      {%- for paper in preprints -%}
      <a class="tty-paper" href="{{ paper.pdf }}" target="_blank" rel="noreferrer noopener">
        <div class="tty-paper__index">{{ (preprints.length - loop.index0) | pad3 }}</div>
        <div class="tty-paper__body">
          <h2 class="tty-paper__title">{{ paper.title }}</h2>
          <p class="tty-paper__authors">{{ paper.authors }}</p>
        </div>
        <div class="tty-paper__meta">
          <span>{{ paper.venue }}</span>
          <time datetime="{{ paper.date }}">{{ paper.date }}</time>
          <span class="tty-paper__ext" aria-hidden="true">pdf →</span>
        </div>
      </a>
      {%- endfor -%}
    </div>
  </section>
</div>
```

Two notes on the template.

The index number: Nunjucks has no `padStart`, and this project registers no `format`
filter. The template above calls `pad3`, so register that filter in `.eleventy.js` before
you build. This is the second `.eleventy.js` edit in the Files list, and it sits beside the
Task 7 filters:

```js
  // Zero-padded three-digit index, for a list that is not a post collection.
  eleventyConfig.addFilter("pad3", (n) => String(n).padStart(3, "0"));
```

`postIndexes` already pads post rows, so `pad3` exists only for lists that are not post
collections — the papers today, anything similar later.

The count: it goes through `plural`, the Task 10 filter, so one paper reads `1 paper`. The
singular and the plural word are both i18n keys, added in Step 7.


- [ ] **Step 7: Confirm the i18n strings are already there**

This task writes no i18n string. Task 5 Step 7 owns `src/_data/i18n/en.json` and already
lands the `preprints.*` keys. Confirm, rather than edit:

```bash
python3 -c "import json;d=json.load(open('src/_data/i18n/en.json'));print(sorted(d['preprints']))"
```

Expected: `['description', 'openHint', 'paper', 'papers', 'title']`.

- [ ] **Step 8: List the page in llms.txt and open the nav tab**

In `src/llms.njk`, add one line to the `## About` section, after the homepage entry:

```njk
- [Preprints]({{ seo.baseUrl }}/preprints/): papers and preprints
```

This task is also where the `preprints` nav tab appears. Task 5 gates every tab on the
build writing its page, and Task 5 Step 1 put this line in the `page shell` section of
`scripts/check-build.sh`:

```bash
grep_not "index.html" 'href="/preprints/"' "the nav ships no tab for a page the build does not write"
```

That line is true for Tasks 5 to 12 and false from here on, because Step 6 writes the page
and the gate opens. Replace that one line with its opposite. Keep it in the `page shell`
section, where Task 5 put it:

```bash
grep_in "index.html" 'href="/preprints/"' "the nav tab for preprints opens once the page exists"
```

Change nothing else in that section. One assertion goes and one arrives, so no
expected-failure count moves. Skip this edit and every task from here to Task 17 reports
FAIL on a line that is doing its job.

- [ ] **Step 9: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 10: Look at the page**

Run: `bun run start` and open `http://localhost:8080/preprints/`.
Expect: `PREPRINTS` in Silkscreen, `1 paper` beside it — the singular, because the count
goes through the `plural` filter — the paper row numbered `001` with the five authors under
the title, and `preprint · 2026-09-21 · pdf →` on the right. Click
the row: the PDF opens in a new tab and renders. The `preprints` nav tab is yellow.
Stop the server before you run the check again.

- [ ] **Step 11: Commit**

```bash
git add src/_data/preprints.js src/en/preprints.njk .eleventy.js src/styles/tty/layout.css src/_data/i18n/en.json src/llms.njk scripts/check-build.sh
git commit -m "feat(preprints): add the preprints page

One row per paper — title, author list, venue and date — linking straight to
the PDF in a new tab. The list comes from src/_data/preprints.js and the PDFs
are copied from the repository-root preprints/ directory, which the build was
not shipping at all before this.

The metadata for the corporate truck factor paper is read off the PDF itself.
It carries no venue line, so venue reads 'preprint'."
```

---
### Task 14: Rebuild the homepage

`/` is the `About.jsx` screen: the biography in prose, an "Elsewhere" list, a `whoami`
terminal, and a short recent-posts rail.

**Do not rewrite the biography.** It is the owner's own writing about their own life. Three
changes, and no more:

1. The waving-hand emoji goes, because the design system forbids emoji. `Hi there, 👋! My
   name is Ellian Carlos.` becomes `Hi there! My name is Ellian Carlos.` The emoji goes and
   the comma that introduced it goes with it. The exclamation mark stays.
2. The two `<h3>` section headings become `<h2>`, so they pick up the Silkscreen yellow
   treatment from `prose.css`.
3. The closing paragraph keeps its sentence, but the inline `Read my Blog!` link inside it
   becomes the button below it. The sentence ends `…you can read my posts.` and the button
   carries the label.

Every other sentence stays word for word.

**Two exclamation marks stay.** "…a son to loving parents!" and "I am learning Rust
continously!" keep theirs. The design system's "no exclamation marks" rule governs UI
strings — labels, hints, empty states, button text — not the owner's own writing. Do not
edit the owner's voice here, and do not silently correct the `continously` typo either. The
Self-Review asks the owner about that typo instead.

**Files:**
- Modify: `src/en/index.njk` (new markup, same words)
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `tty.btn`, `tty.divider` (Task 3), `ttyc.terminal`, `ttyc.foldout` (Task 4),
  `.tty-split--rail-wide`, `.tty-rail`, `.tty-rail--sticky`, `.tty-when-desktop`,
  `.tty-when-compact`, `.tty-linklist` (Task 5), `.tty-menu` (Task 3), `readingTime`
  (Task 7), `seo.social.*`.
- Consumes these i18n keys, all of them from the complete `en.json` Task 5 writes:
  `nav.about`, `nav.academicCv`, `blog.recent`, `blog.readPosts`, `footer.elsewhere`. This
  task adds no key of its own. If `blog.readPosts` is missing, go back to Task 5 Step 7 and
  add it there; do not add a second copy here.
- Produces no new class and no new filter. It declares one local `{% macro rail() %}`, for
  the same reason `archive.njk` does: the desktop aside and the compact `<details>` render
  from one source.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "homepage"
grep_in "index.html" 'class="tty-prose"' "the biography is inside the prose wrapper"
grep_in "index.html" 'class="tty-term"' "the whoami terminal is present"
grep_in "index.html" 'class="tty-linklist"' "the elsewhere list is present"
grep_in "index.html" 'class="tty-menu' "the recent rail is present"
grep_in "index.html" 'class="tty-linklist__key">resume<' "the elsewhere list carries the resume row"
grep_in "index.html" 'class="tty-linklist__key">cv<' "the elsewhere list carries the academic cv row"
grep_in "index.html" "Brazilian software engineer" "the biography text survives"
grep_in "index.html" "I love languages" "the rest of the biography survives"
grep_in "index.html" "other topics I like to discuss" "the closing biography sentence survives"
grep_not "index.html" "👋" "the waving hand emoji is gone"
grep_not "index.html" 'class="button"' "the old Pico button class is gone"
grep_in "index.html" 'class="tty-btn tty-btn--primary"' "the blog call to action is a design system button"
grep_in "index.html" "Read the posts" "the call to action names its destination"
grep_not "index.html" "Read the archive" "the homepage does not borrow the archive label"

The resume and the academic cv are asserted through their `tty-linklist` rows, not through
their URLs. Task 5's footer already carries both URLs, so a URL assertion here would pass
before this task writes a line of markup.
```

Add one more assertion, in a new section, that holds for the whole site from here on:

```bash
section "no emoji anywhere"
# Byte patterns, not PCRE. `grep -P` reads `\x{1F300}` only in a UTF-8 locale: under
# LC_ALL=C, GNU grep 3.8 exits 2 with "character code point value in \x{} or \o{} is too
# large", and an `if` reads that exit status as "no emoji found". These three alternatives
# are the UTF-8 lead bytes of the emoji planes (U+1F000-U+1FFFF), of the symbol and dingbat
# blocks (U+2600-U+27BF), and of the emoji variation selector U+FE0F.
EMOJI_BYTES=$'\xf0\x9f|\xe2[\x98-\x9e]|\xef\xb8\x8f'
# Three code points of the design system's own glyph vocabulary sit inside those blocks.
# Delete them before the scan so a sanctioned glyph cannot read as an emoji.
strip_glyphs() { LC_ALL=C sed -e 's/✓//g' -e 's/✕//g' -e 's/⚿//g' "$1"; }
has_emoji() { strip_glyphs "$1" | LC_ALL=C grep -qE "$EMOJI_BYTES"; }

# The matcher tests itself, both ways. A broken matcher fails loudly instead of passing
# every file in silence, which is what the `grep -P` form did.
probe="$(mktemp)" || { bad "the emoji matcher cannot run: mktemp is missing"; probe=""; }
if [ -n "$probe" ]; then
  printf 'probe \xf0\x9f\x91\x8b and \xe2\x9c\x85 and \xef\xb8\x8f\n' > "$probe"
  if has_emoji "$probe"; then pass "the emoji matcher detects an emoji"
  else bad "the emoji matcher is broken: it cannot see a known emoji"; fi
  printf 'glyphs \xe2\x96\xaa \xe2\x97\x8b \xe2\x97\x8f \xe2\x9c\x95 ascii\n' > "$probe"
  if has_emoji "$probe"; then bad "the emoji matcher rejects the design system glyphs"
  else pass "the emoji matcher accepts the design system glyphs"; fi
  rm -f "$probe"
fi

for f in index.html 404.html posts/index.html posts/archive/index.html preprints/index.html contact/index.html; do
  if [ ! -f "$DIST/$f" ]; then printf '  --   skip no emoji in %s (not built yet)\n' "$f"; continue; fi
  if has_emoji "$DIST/$f" ; then bad "no emoji in $f"; else pass "no emoji in $f"; fi
done
```

Two notes on that block. A page that does not exist yet prints a `skip` line instead of a
silent nothing, so a missing page cannot look like a clean one. And the section scans the
pages this migration writes, not the posts: the no-emoji rule is a rule about the interface,
and a post is the owner's words.

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — ten of the fourteen `homepage` assertions, from `the biography is inside
the prose wrapper` to `the call to action names its destination`, plus `no emoji in
index.html`.

Four `homepage` assertions pass before the rewrite: the three that check the biography text
survives, and `the homepage does not borrow the archive label`. They are regression guards,
not new behaviour.

Both matcher self-tests must report `ok`. If `the emoji matcher detects an emoji` reports
`FAIL`, fix the harness before you touch the homepage: an emoji check that cannot see an
emoji passes every page for the wrong reason.

- [ ] **Step 3: Rewrite the homepage**

Replace the whole of `src/en/index.njk` with this. The biography paragraphs are unchanged
except for the removed emoji in the first sentence.

```njk
---
title: Home
seoTitle: Ellian Carlos
description: Software engineer at Amazon and CS master's candidate at USP, researching open source and the Linux kernel. Writing on tools, languages, and systems.
layout: layouts/layout.njk
---
{% import "tty/core.njk" as tty %}
{% import "tty/content.njk" as ttyc %}
{%- set recent = collections.postsActive_en -%}

{% macro rail() %}
<div class="tty-rail">
  {% call ttyc.terminal("whoami", "dots") %}
    <div class="tty-term__line"><span class="tty-term__prompt" aria-hidden="true">$</span> <span>whoami</span></div>
    <div class="tty-term__out">ellian</div>
    <div class="tty-term__line" style="margin-top: 8px"><span class="tty-term__prompt" aria-hidden="true">$</span> <span>pwd</span></div>
    <div class="tty-term__out">/brazil/sao-paulo</div>
    <div class="tty-term__line" style="margin-top: 8px"><span class="tty-term__prompt" aria-hidden="true">$</span> <span>groups</span></div>
    <div class="tty-term__out">amazon ime-usp</div>
  {% endcall %}
  <div>
    {{ tty.divider(i18n.en.blog.recent) }}
    <ul class="tty-menu tty-menu--dense" style="margin-top: 10px">
      {%- for post in recent -%}
      {%- if loop.index <= 4 -%}
      <li>
        <a class="tty-menu__item" href="{{ post.url }}">
          <span class="tty-menu__cursor" aria-hidden="true">›</span>
          <span class="tty-menu__label">{{ post.data.title }}</span>
          <span class="tty-menu__hint">{{ post | readingTime }}</span>
        </a>
      </li>
      {%- endif -%}
      {%- endfor -%}
    </ul>
  </div>
</div>
{% endmacro %}

<div class="tty-split tty-split--rail-wide">
  <div>
    <h1 class="tty-h1">{{ i18n.en.nav.about }}</h1>

    <div class="tty-when-compact">
      {% call ttyc.foldout(i18n.en.blog.recent, "4 posts") %}
        {{ rail() }}
      {% endcall %}
    </div>

    <div class="tty-prose" style="margin-top: 22px">
      <p>
      Hi there! My name is Ellian Carlos. I'm a Brazilian software engineer and computer science master's candidate in USP. I'm also a husband to a loving wife and a son to loving parents!
      </p>
      <p>
      I'm a Software Development Engineer at Amazon, and I hold a bachelor's in Information Systems from the ICMC, an institute of the University of São Paulo.
      My role extends beyond coding; I am a Problem Solver and Teacher, most of my work is to disambiguate problems, remove blockers and enable technical solutions to take form.
      I write a lot of documents to enable leadership and S-teams of our engineering teams, operate on an excellence level and impact the customer experience.
      </p>
      <p>
      I love languages, both the humans and the computer ones. Right now, I'm working with Kotlin, TypeScript, Python and others. I'm always studying architecture, scalability and functional programming. I am learning Rust continously! I also know some C/C++.
      About the human languages, I'm fluent in Portuguese and English. I'm learning Spanish and Japanese and I want to learn Mandarin and German someday.
      Besides the languages I'm working with I also use AWS, Docker, SQL and other tools.
      </p>
      <p>
      I can't emphasize how much I like studying, I love to dive deep into technical details and to get lost into mathematical representations of the world and computers.
      I am curious about almost everything, also I don't have a specific type of learning, I like practical or theoretical things, readings, lectures or hands-on projects, everything is valid.
      </p>
      <p>
      I also love teaching, I would never be good student if it wasn't for the incredible teachers I had in my journey.
      As I see it, one of my main missions is to form other engineers, be it by teaching or creating an environment where innovation and excitement can guide new people into their learning journey.
      </p>

      <h2>Currently</h2>
      <p>
      I'm pursuing my master's degree with a focus on Open Source development, while deepening my expertise in Rust and systems architecture and design. At Amazon, I'm contributing to governmental compliance solutions that enable the company's global expansion. I'm also exploring the potential of agentic AI to enhance development workflows and problem-solving approaches.
      </p>

      <h2>My Beliefs</h2>
      <p>
      I believe that the world is built by people and for people. I believe that all education and knowledge should be free to all and with equal opportunity to access.
      I also believe that we all are keepers of the world and ourselves and we should honor that.
      </p>
      <p>
      As a Software Engineer I believe that we have an indirect impact on the world by the applications we build and resources we use.
      This implies a responsibility to be frugal with energy resources and to provide accessibility as a must in all our applications.
      </p>
      <p>
      If you want to know my tools, opinions and other topics I like to discuss, you can read my posts.
      </p>
    </div>

    <div style="margin-top: 26px">
      {{ tty.btn(i18n.en.blog.readPosts, "/posts/", "primary") }}
    </div>

    <div style="margin-top: 34px">
      {{ tty.divider(i18n.en.footer.elsewhere) }}
      <div class="tty-linklist" style="margin-top: 14px">
        <div class="tty-linklist__row">
          <span class="tty-linklist__key">git</span>
          <a href="{{ seo.social.github }}" target="_blank" rel="noreferrer noopener">github.com/elliancarlos</a>
        </div>
        <div class="tty-linklist__row">
          <span class="tty-linklist__key">work</span>
          <a href="{{ seo.social.linkedin }}" target="_blank" rel="noreferrer noopener">linkedin.com/in/elliancarlos</a>
        </div>
        <div class="tty-linklist__row">
          <span class="tty-linklist__key">social</span>
          <a href="{{ seo.social.mastodon }}" target="_blank" rel="me noreferrer noopener">mastodon.social/@elliancarlos</a>
        </div>
        <div class="tty-linklist__row">
          <span class="tty-linklist__key">orcid</span>
          <a href="{{ seo.social.orcid }}" target="_blank" rel="noreferrer noopener">orcid.org/0009-0004-9135-8207</a>
        </div>
        <div class="tty-linklist__row">
          <span class="tty-linklist__key">cv</span>
          <a href="{{ seo.social.lattes }}" target="_blank" rel="noreferrer noopener">{{ i18n.en.nav.academicCv }}</a>
        </div>
        <div class="tty-linklist__row">
          <span class="tty-linklist__key">resume</span>
          <a href="/Ellian_Carlos_Resume.pdf">Ellian_Carlos_Resume.pdf</a>
        </div>
        <div class="tty-linklist__row">
          <span class="tty-linklist__key">feed</span>
          <a href="/feed.xml">feed.xml</a>
        </div>
      </div>
    </div>
  </div>

  <aside class="tty-rail--sticky tty-when-desktop">
    {{ rail() }}
  </aside>
</div>
```

Note the button label. It is `blog.readPosts` (`Read the posts`), not `blog.readArchive`.
The button opens `/posts/`, the reading landing page, and `/posts/archive/` is a different
page that Task 11 creates. `blog.readArchive` stays bound to `/posts/archive/`, where
Task 10 uses it. A label must name its own destination, so the two strings are separate and
each one can be corrected in one place.

`blog.readPosts` is added with the rest of the `blog` object in Task 5 Step 7, which owns
the complete `en.json`. Check it is there before you run the build; do not add a second copy
of the key from this task.

- [ ] **Step 4: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 5: Look at the homepage**

Run: `bun run start` and open `http://localhost:8080/`.
Expect: `ABOUT` in Silkscreen, the biography at the 68ch measure in JetBrains Mono, two
yellow Silkscreen section headings, the closing sentence about tools and opinions, a yellow
`READ THE POSTS` button under that sentence, and the `ELSEWHERE` key/value list.
Read the first sentence too. It must read `Hi there! My name is Ellian Carlos.` — no emoji,
no lost punctuation.
On the right: the `whoami` terminal with three coloured dots and a green `$` prompt, then a
`RECENT` list of four posts with reading times. Narrow below 1280px: the rail folds into a
`▸ RECENT` disclosure under the title.
Stop the server before you run the check again.

- [ ] **Step 6: Commit**

```bash
git add src/en/index.njk scripts/check-build.sh
git commit -m "feat(design): rebuild the homepage on the About screen

Three changes to the biography, and no more: the waving-hand emoji goes, the
two section headings move from h3 to h2 so they pick up the Silkscreen yellow
treatment, and the closing paragraph keeps its sentence while its inline link
becomes the button under it. Every other sentence is word for word, including
the two exclamation marks: the no-exclamation rule is about UI strings, not
about the owner's own writing.

The button is labelled Read the posts and opens /posts/. It no longer borrows
the archive label, which belongs to /posts/archive/.

Around the biography: an Elsewhere key/value list carrying the resume and
academic cv the nav no longer holds, a whoami terminal, and a recent-posts rail
that folds into a disclosure under 1280px.

A site-wide emoji check joins the harness. It matches UTF-8 bytes instead of
grep -P: under LC_ALL=C, GNU grep rejects \\x{1F300} and exits 2, which the old
form read as a pass, so the check could never fail. It now tests itself both
ways before it scans."
```

---

### Task 15: Restyle the contact and 404 pages

The two remaining pages. Both are small. The 404 page also carries dead JavaScript after
Task 5 — it reaches for `#language-select` and `.page-header-content h1`, and neither
element exists any more.

**Do not change the contact email address.** `src/en/contact.njk` shows
`elliancarlos@example.com`, which looks like a placeholder — the preprint PDF gives
`elliancarlos@gmail.com`. Publishing a real address is the owner's decision, not a
migration decision. Keep the current value and **ask**.

**Files:**
- Modify: `src/en/contact.njk` (full rewrite)
- Modify: `src/en/404.njk` (new markup, dead script removed)
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `tty.btn`, `tty.divider` (Task 3), `.tty-linklist`, `.tty-h1`, `.tty-prose`,
  `.tty-screen` (Tasks 4, 5), `seo.social.*`.
- Consumes the i18n keys `contact.title`, `contact.email`, `error.title`, `error.message`
  and `error.home`. They all come from the complete `en.json` that Task 5 Step 7 writes.
  This task adds no key and does not edit `en.json`. If a key is missing, add it in Task 5
  Step 7; do not make a second copy of it here.
- Produces no new class and no new filter.
- Removes the 404 language-selector block. The browser-language redirect at the head of
  that script stays: it still bounces `/pt/...` to `/...`, which is live behaviour.
- Removes the 404 language-selector block. The browser-language redirect at the head of
  that script stays: it still bounces `/pt/...` to `/...`, which is live behaviour.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "contact and error pages"
have "contact/index.html"
grep_in "contact/index.html" 'class="tty-linklist"' "contact uses the key/value list"
grep_in "contact/index.html" 'class="tty-h1"' "contact has a display title"
grep_not "contact/index.html" "<ul>" "the old plain list is gone from contact"
grep_in "404.html" 'class="tty-h1"' "the 404 page has a display title"
grep_in "404.html" 'class="tty-btn' "the 404 page offers a way home"
grep_not "404.html" "language-select" "the dead language selector script is gone"
grep_not "404.html" "page-header-content" "the dead page header lookup is gone"
grep_in "404.html" "strippedPath" "the language-prefix redirect survives"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `contact uses the key/value list`, `the dead language selector script is
gone`, and five more.

- [ ] **Step 3: Rewrite the contact page**

Replace the whole of `src/en/contact.njk` with:

```njk
---
title: Contact
description: Get in touch with Ellian Carlos via email or social media.
layout: layouts/layout.njk
---
{% import "tty/core.njk" as tty %}
{#
  The email address below is the one this page has always shown. It looks like a
  placeholder; changing a published address is the owner's call, not this
  migration's. Ask before you touch it.
#}
<div class="tty-screen">
  <section>
    <h1 class="tty-h1">{{ i18n.en.contact.title }}</h1>
    <div class="tty-linklist" style="margin-top: 22px">
      <div class="tty-linklist__row">
        <span class="tty-linklist__key">{{ i18n.en.contact.email }}</span>
        <a href="mailto:elliancarlos@example.com">elliancarlos@example.com</a>
      </div>
      <div class="tty-linklist__row">
        <span class="tty-linklist__key">git</span>
        <a href="{{ seo.social.github }}" target="_blank" rel="noreferrer noopener">github.com/elliancarlos</a>
      </div>
      <div class="tty-linklist__row">
        <span class="tty-linklist__key">work</span>
        <a href="{{ seo.social.linkedin }}" target="_blank" rel="noreferrer noopener">linkedin.com/in/elliancarlos</a>
      </div>
      <div class="tty-linklist__row">
        <span class="tty-linklist__key">social</span>
        <a href="{{ seo.social.mastodon }}" target="_blank" rel="me noreferrer noopener">mastodon.social/@elliancarlos</a>
      </div>
      <div class="tty-linklist__row">
        <span class="tty-linklist__key">orcid</span>
        <a href="{{ seo.social.orcid }}" target="_blank" rel="noreferrer noopener">orcid.org/0009-0004-9135-8207</a>
      </div>
    </div>
  </section>
</div>
```

- [ ] **Step 4: Rewrite the 404 page**

Replace the whole of `src/en/404.njk` with:

```njk
---
layout: layouts/layout.njk
title: 404
seoTitle: Page Not Found
description: The page you're looking for doesn't exist.
type: error
eleventyExcludeFromCollections: true
permalink: /404.html
---
{% import "tty/core.njk" as tty %}
<div class="tty-screen">
  <section>
    <p class="tty-eyebrow">status 404</p>
    <h1 class="tty-h1" id="error-title" style="margin-top: 18px">{{ i18n.en.error.title }}</h1>
    <p class="tty-prose tty-prose--md" id="error-message" style="margin-top: 18px">{{ i18n.en.error.message }}</p>
    <div style="margin-top: 26px">
      <a class="tty-btn tty-btn--primary" id="error-link" href="/">{{ i18n.en.error.home }}</a>
    </div>
  </section>
</div>

<script>
  // A language-prefixed URL that was never translated (e.g. /pt/posts/xxx) bounces
  // to the English path instead of showing a 404. This is the only script this page
  // needs; the language selector it used to update no longer exists.
  (function() {
    const path = window.location.pathname;
    const langPrefix = path.match(/^\/(pt|es|ja)\/(.*)$/);
    if (langPrefix) {
      const strippedPath = '/' + langPrefix[2];
      if (strippedPath !== path) {
        window.location.replace(strippedPath);
      }
    }
  })();
</script>
```

The per-language 404 copy table is gone with the selector. It only ever fired on
`/pt/`, `/es/` and `/ja/` paths, and the redirect above now sends those to the English page
before any of it could run.

- [ ] **Step 5: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

This task writes no i18n string. Task 5 Step 7 owns `src/_data/i18n/en.json` and already
holds `contact.title`, `contact.email`, `error.title`, `error.message` and `error.home` at
their final values. If a label renders empty, go back to Task 5 Step 7 and correct the key
there. Do not add an `error` object here: a second copy of the same key in one JSON file is
a silent last-one-wins edit.

- [ ] **Step 6: Look at both pages**

Run: `bun run start`. Open `http://localhost:8080/contact/` and
`http://localhost:8080/not-a-real-page`.
Expect contact: `CONTACT` in Silkscreen over a key/value list with yellow links.
Expect 404: the `STATUS 404` eyebrow, `PAGE NOT FOUND` in Silkscreen, one sentence, and a
yellow `GO HOME` button. Check the browser console is clean — no `null` reference from the
old selector code.
Stop the server before you run the check again.

- [ ] **Step 7: Commit**

```bash
git add src/en/contact.njk src/en/404.njk scripts/check-build.sh
git commit -m "feat(design): restyle the contact and 404 pages

Contact becomes a key/value list; the 404 page becomes an eyebrow, a display
title, one sentence and a button. The 404 script loses the language selector
and per-language copy table it was driving — Task 5 deleted the elements they
reached for. The language-prefix redirect stays, because it is live behaviour.

The contact email is left exactly as it was: it reads like a placeholder, and
changing a published address is the owner's call."
```

---
### Task 16: Delete the dead code and update the documentation

Every screen is migrated, so the Pico-era files and helpers have no consumer left. Remove
them, then bring the two documents that describe this repository back in step with it.

**Files:**
- Modify: `.eleventy.js` (remove `sneakPeak`, `sneakPeakPost`, `postInLanguage`)
- Modify: `CLAUDE.md`
- Modify: `README.md:15`
- Modify: `scripts/check-build.sh`
- Delete: `src/styles/style.css`
- Delete: `src/styles/blog.css`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: nothing new.
- Produces nothing new. This task only removes and documents.

- [ ] **Step 1: Prove the code really is dead**

Run all four and expect no match from any of them:

```bash
grep -rn "sneakPeakPost" src/ || echo "sneakPeakPost: unused"
grep -rn "postInLanguage" src/ || echo "postInLanguage: unused"
grep -rn "styles/style.css\|styles/blog.css" src/ || echo "old stylesheets: unlinked"
grep -rn "relative_path" src/ || echo "relative_path: unset everywhere"
```

If any of these *does* match, stop. Something earlier in the plan was skipped — find it and
finish that task before you delete anything here.

- [ ] **Step 2: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "dead code is gone"
if [ -f "$DIST/styles/style.css" ]; then bad "styles/style.css is deleted"; else pass "styles/style.css is deleted"; fi
if [ -f "$DIST/styles/blog.css" ]; then bad "styles/blog.css is deleted"; else pass "styles/blog.css is deleted"; fi
if [ -f "$DIST/scripts/search.js" ]; then bad "scripts/search.js is deleted"; else pass "scripts/search.js is deleted"; fi
have "scripts/tty-search.js"
have "scripts/tty-progress.js"
have "scripts/tty-typewriter.js"
have "scripts/tty-archive.js"
```

- [ ] **Step 3: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — `styles/style.css is deleted` and `styles/blog.css is deleted`.
`scripts/search.js` already passes, because Task 9 removed it, but `dist/` may still hold a
stale copy. Run `bun run clean && bun run build` once here so the assertions read a fresh
tree rather than leftovers.

- [ ] **Step 4: Delete the old stylesheets**

```bash
git rm src/styles/style.css src/styles/blog.css
```

`src/styles` keeps its passthrough copy in `.eleventy.js:99` — that line now carries
`tty.css` and the `tty/` directory, so leave it alone.

- [ ] **Step 5: Remove the dead filters and helper**

In `.eleventy.js`, delete three regions:

1. The whole `sneakPeak` function (lines 36-60 in the original file, the one that builds a
   255-character excerpt and hunts for an `<img>` tag).
2. The `sneakPeakPost` filter registration near the end of the module:
   ```js
   eleventyConfig.addFilter("sneakPeakPost", function (data) {
     return sneakPeak(data.content)
   });
   ```
3. The whole `postInLanguage` filter. Nothing has ever called it — it was written for a
   translation-aware post list that the repository never grew.

Keep `leftPadDate`: the `postDate` filter calls it, and every date on the site goes through
`postDate`.

Keep `switchLanguage`, `i18nUrl`, the `availableUrls` collection, `languageRedirect.njk`
and the `permalink` global. They are the i18n machinery `CLAUDE.md` documents, and the
templates still call `i18nUrl` on every internal link. Deleting them would break the
flag-flip path the repository deliberately keeps.

- [ ] **Step 6: Update CLAUDE.md**

In `CLAUDE.md`, make five edits.

First, in the `## Overview` paragraph, replace the sentence about styling. Change

> Personal website/blog (elliancarlos.com.br) built with **Eleventy (11ty) 2.x**, Nunjucks
> templates, and Markdown content.

so the paragraph continues with one more sentence:

```markdown
The visual layer is the **TTY design system** — a TUI-flavoured system vendored into
`src/styles/tty/`. Pico CSS was removed in the design system migration.
```

Second, add a new section directly after `## Commands`:

```markdown
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
```

Third, add a new section after `### Blog features`:

```markdown
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
```

Fourth, replace the verification sentence in `## Commands`. Change

> There is **no test suite, linter, or typecheck** — verification means running
> `bun run build` and inspecting `dist/`.

to

```markdown
There is **no unit test suite, linter, or typecheck**. Verification is
`bun run build && ./scripts/check-build.sh` — an assertion harness over the built `dist/`
tree. It never builds, so it cannot fight `eleventy --serve`; stop the dev server before
you build. Inside the devenv shell, `check` does both steps. CI runs the same script.

**Add an assertion to `scripts/check-build.sh` for every change you make.** It is the only
regression net this repository has.
```

Fifth, list the one frontmatter key this migration adds. In the `### Post frontmatter` yaml
block, after the `modified: 2025-08-01  # optional; shows "updated on"` line, add

```yaml
archived: true        # optional; drops the post from /posts/ only, see "Archived posts"
```

The flag is described in full in the new `### Archived posts` section, but the frontmatter
block is where an author looks a key up, so it must name the key too.

- [ ] **Step 7: Update the README**

In `README.md`, change the `Styles` row of the Stack table from

```markdown
| Styles                  | [Pico CSS](https://picocss.com/) 2                               |
```

to

```markdown
| Styles                  | TTY design system (vendored, `src/styles/tty/`)                   |
```

Then add one row under it:

```markdown
| Build check             | `scripts/check-build.sh` (assertions over `dist/`)                |
```

- [ ] **Step 8: Run the check on a clean tree**

Run: `bun run clean && bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`, with no `FAIL` line anywhere in the
output.

- [ ] **Step 9: Walk the whole site once**

Run: `bun run start` and visit every URL. All of them must render, and the browser console
must be clean on each:

```
/
/posts/
/posts/archive/
/posts/my-tools-2025/
/posts/my-tools-2024/
/posts/tag/linux/
/preprints/
/contact/
/not-a-real-page
```

On `/posts/archive/`, click both sort buttons. On any page, press `/` and search. Stop the
server afterwards.

- [ ] **Step 10: Commit**

```bash
git add -A .eleventy.js src/styles CLAUDE.md README.md scripts/check-build.sh
git commit -m "chore: remove the Pico-era code and update the docs

style.css, blog.css, the sneakPeak excerpt helper and its filter, and the
never-called postInLanguage filter all lost their last consumer when the
screens migrated. The i18n machinery stays — templates still call i18nUrl, and
the flag-flip path documented in CLAUDE.md needs the rest of it.

CLAUDE.md gains a design system section, the archived-post rules and the
preprints workflow, and both documents now name check-build.sh as the
verification step instead of 'inspect dist/'."
```

---

### Task 17: Markdown fidelity pass

Task 6 styled the Markdown a post *usually* contains. This task covers what these posts
*actually* contain. Four things in the existing 14 posts break or look wrong under the
design system, and three of them are regressions this migration would otherwise introduce.

**Run this task after Task 8, not after Task 6.** Every rule here is scoped to
`.tty-prose`, and Task 8 is what puts the post body inside `<div class="tty-prose">`. Run it
earlier and three of the four checks in Step 6 fail for a reason that has nothing to do with
this task, because no post body carries the class those rules select on yet. The dependency
is Task 6 for the file and Task 8 for the wrapper.

Run this survey first, so you are fixing measured problems and not imagined ones:

```bash
cd src/en/posts
grep -lE "^\|" *.md                  # posts with a table
grep -lE "^- \[[ x]\]" *.md          # posts with a task list
grep -lE '^<div style="display: flex' *.md   # posts with a centred figure
grep -hE "^\|" *.md | awk '{print length}' | sort -rn | head -1   # widest table row
cd -
```

Today that reports one post with a table whose widest row is 171 characters, one post with
a task list, and three posts using 15 centred-figure blocks with 13 captions.

The four problems:

1. **A 171-character, four-column table inside a 68ch measure.** `tokens/breakpoints.css`
   ends with `html, body { overflow-x: hidden; }`, so the overflow is *clipped*, not
   scrolled, and two columns become unreachable. The Pico site did not have that rule, so
   this is a regression the vendored tokens introduce.
2. **Task lists collide with the new list marker.** `markdown-it` has no task-list rule
   here, so `- [ ] text` renders as a list item whose text begins with a literal `[ ]`.
   Task 6 added a `▪` block marker to every `ul > li`, so the reader now sees
   `▪ [ ] text` — two markers. Also a regression.
3. **Centred figure captions read as body copy.** The posts wrap figures in
   `<div style="display: flex; justify-content: center;">` and follow them with
   `<p style="text-align: center;"><em>…</em></p>`. Those captions render at the 17px body
   size in body colour, indistinguishable from the prose around them.
4. **The figures shrink.** Today the post body sits in Pico's container and the plots
   render about 1060px wide. `.tty-prose` is 68ch, about 694px at 17px, so a four-panel
   chart like `kc-ownership-over-time.png` (2101×479) loses a third of its width and its
   axis labels with it. Twelve plots in
   `measuring-corporate-knowledge-concentration-in-the-linux-kernel.md` and the
   `cregit-token-blame.png` screenshot are affected. That is a regression too.

**No new package.** All four are fixed with three `markdown-it` rules and some CSS. A
`markdown-it-task-lists` dependency would emit a disabled `<input type="checkbox">` — a dead
control on a static page, and a checkbox is not in the design system's vocabulary anyway.
The task glyphs are `○` (U+25CB) for open and `●` (U+25CF) for done. Both are in the
design system's glyph vocabulary, and both are Geometric Shapes, so one font fallback covers
the pair. Do not use `▣`: it is not in that vocabulary.

**Files:**
- Modify: `.eleventy.js` (three rules inside the existing `amendLibrary("md", …)` block at
  lines 85-92; no new filter)
- Modify: `src/styles/tty/prose.css` (append)
- Modify: `scripts/check-build.sh`
- Test: `scripts/check-build.sh`

**Interfaces:**
- Consumes: `.tty-prose` and its descendant rules (Tasks 4 and 6), the tokens (Task 2), and
  the `.tty-prose` wrapper Task 8 puts around the post body.
- Produces the CSS classes appended to `prose.css`: `.tty-scroll`, `.tty-task`,
  `.tty-task--on`, `.tty-task--off`, `.tty-caption`, `.tty-figure`, plus one custom
  property, `--font-marker`, scoped to `.tty-prose`.
- Produces three `markdown-it` behaviours. All are build-time only; the browser receives
  plain HTML:
  - `table_open` / `table_close` renderer rules wrap every Markdown table in
    `<div class="tty-scroll">`.
  - A core ruler named `tty_task_glyphs` strips a leading `[ ]`, `[x]` or `[X]` off the
    first text node of a **bullet** list item and puts `tty-task` plus `tty-task--off` or
    `tty-task--on` on the `<li>`. An item in an ordered list keeps its literal `[ ]`,
    because the CSS marker is scoped to `ul > li` and an `<ol>` item already has a number.
- Produces no change to how a post is written. A `.md` file with frontmatter is still the
  whole authoring interface. `.tty-caption` and `.tty-figure` are *optional* classes a new
  post may use; the attribute selectors keep the 15 existing inline-styled blocks working
  with no content edit.

- [ ] **Step 1: Write the failing assertions**

Add to `scripts/check-build.sh`, before the closing `printf '\n'` block:

```bash
section "markdown fidelity"
grep_in "posts/notes-on-the-contribution-for-the-linux-kernel/index.html" '<div class="tty-scroll"><table>' "every table is wrapped in a scroller"
grep_in "styles/tty/prose.css" ".tty-scroll" "the scroll wrapper is styled"
grep_in "styles/tty/prose.css" "thead th { white-space: nowrap" "table headers stay on one line"
grep_not "styles/tty/prose.css" "tbody td { white-space: nowrap" "body cells are free to wrap"
grep_in "posts/how-to-succeed-in-ai-assisted-coding-interviews/index.html" 'class="tty-task tty-task--off"' "an open task item is marked"
grep_not "posts/how-to-succeed-in-ai-assisted-coding-interviews/index.html" '<li>[ ] AI-assisted' "the literal checkbox text is gone"
grep_not "posts/how-to-succeed-in-ai-assisted-coding-interviews/index.html" 'type="checkbox"' "no dead checkbox control is emitted"
grep_in "styles/tty/prose.css" 'content: "●"' "a completed task shows the filled glyph"
grep_in "styles/tty/prose.css" "--font-marker" "the list marker glyphs have a fallback stack"
grep_in "styles/tty/content.css" "var(--measure-wide)" "a figure may exceed the text measure (Task 4 owns this rule)"
grep_in "styles/tty/prose.css" 'text-align: center' "the existing centred captions are matched"
grep_in "styles/tty/prose.css" "overflow-wrap" "long urls wrap inside the measure"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bun run build && ./scripts/check-build.sh`
Expected: FAIL — ten of the twelve `markdown fidelity` assertions, among them `every table
is wrapped in a scroller`, `an open task item is marked` and `the literal checkbox text is
gone`.

Two pass from the start: `body cells are free to wrap` and `no dead checkbox control is
emitted`. Both are `grep_not` guards. They are here to stop a later change reintroducing
what this task removes, not to fail today.

- [ ] **Step 3: Add the two Markdown rules**

In `.eleventy.js`, inside the existing `eleventyConfig.amendLibrary("md", (mdLib) => { … })`
block, after the KaTeX line, add:

```js
    // A wide table must scroll, not disappear. tokens/breakpoints.css ends with
    // `html, body { overflow-x: hidden }`, which clips anything wider than the
    // measure, so every table gets a scroll container of its own.
    const tableOpen = mdLib.renderer.rules.table_open;
    mdLib.renderer.rules.table_open = function (tokens, idx, options, env, self) {
      const rendered = tableOpen
        ? tableOpen(tokens, idx, options, env, self)
        : self.renderToken(tokens, idx, options);
      return '<div class="tty-scroll">' + rendered;
    };
    const tableClose = mdLib.renderer.rules.table_close;
    mdLib.renderer.rules.table_close = function (tokens, idx, options, env, self) {
      const rendered = tableClose
        ? tableClose(tokens, idx, options, env, self)
        : self.renderToken(tokens, idx, options);
      return rendered + "</div>";
    };

    // `- [ ] text` and `- [x] text` become glyph-marked list items.
    // No checkbox element: a disabled control on a static page is dead furniture,
    // and the design system marks state with glyphs. The `[ ]` prefix is stripped
    // from the text so it cannot sit next to the marker CSS draws.
    mdLib.core.ruler.after("inline", "tty_task_glyphs", (state) => {
      const tokens = state.tokens;
      for (let i = 2; i < tokens.length; i += 1) {
        if (tokens[i].type !== "inline") continue;
        // markdown-it always wraps list item content in a paragraph. In a tight
        // list that paragraph is still emitted, only flagged `hidden`. So the
        // <li> token is two back, never one back.
        if (tokens[i - 1].type !== "paragraph_open") continue;
        const li = tokens[i - 2];
        if (li.type !== "list_item_open") continue;
        // Bullet lists only. `markup` holds the bullet character in a bullet
        // list and the delimiter (`.` or `)`) in an ordered one, and the CSS
        // below draws a marker for `ul > li` only.
        if ("-*+".indexOf(li.markup) === -1) continue;
        const children = tokens[i].children;
        if (!children || children.length === 0) continue;
        const first = children[0];
        if (first.type !== "text") continue;
        const match = /^\[([ xX])\]\s+/.exec(first.content);
        if (!match) continue;
        first.content = first.content.slice(match[0].length);
        li.attrJoin("class", "tty-task");
        li.attrJoin(
          "class",
          match[1] === " " ? "tty-task--off" : "tty-task--on"
        );
      }
      return true;
    });
```

Three things about that rule, each one checked against the `markdown-it` Eleventy actually
loads (13.0.2 — find it with
`node -e "console.log(require.resolve('markdown-it',{paths:[require.resolve('@11ty/eleventy')]}))"`):

- `core.ruler.after("inline", …)` runs once the inline tokens have children, which is why
  the rule can read `tokens[i].children[0]`. Registering it before `inline` would find
  nothing.
- The `<li>` is `tokens[i - 2]`, not `tokens[i - 1]`. The stream for one tight checklist
  item is `bullet_list_open / list_item_open / paragraph_open (hidden) / inline /
  paragraph_close / list_item_close`. A rule that guards on
  `tokens[i - 1].type === "list_item_open"` never fires at all, and one that writes the
  class onto `tokens[i - 1]` puts it on the hidden paragraph instead of the `<li>`.
- `[link](url)` is safe. In `- [link](https://x.com) is here` the first child is
  `link_open`, not `text`, so the rule skips the item. `- [not a link] is here` and
  `- [ ]notspaced` are skipped too, because the regular expression needs the closing
  bracket and a space.

Prove the token shape before you trust the offsets:

```bash
node -e '
const md = new (require("markdown-it"))();
md.parse("- [ ] one\n- [x] two\n", {}).forEach((t, i) => console.log(i, t.type, t.hidden ? "hidden" : ""));
'
```

Expect `1 list_item_open`, `2 paragraph_open hidden`, `3 inline`. If your `markdown-it`
prints something else, fix the offsets before you write the CSS.

- [ ] **Step 4: Append the Markdown fidelity CSS**

Append to `src/styles/tty/prose.css`:

```css
/* ── Markdown the posts actually contain ────────────────────────────────── */

/* A long URL or a long identifier must fold inside the 68ch measure rather than
   push the column wider than the page. */
.tty-prose { overflow-wrap: break-word; }
.tty-prose code:not([class*="language-"]) { overflow-wrap: anywhere; }

/* Table scroll container, added by the table_open rule in .eleventy.js.
   tokens/breakpoints.css clips page-level overflow, so a wide table needs a
   scroller of its own or its last columns are unreachable. */
.tty-scroll {
  margin: 0 0 var(--sp-6);
  overflow-x: auto;
  border-bottom: var(--border-w) solid var(--border-faint);
}
.tty-scroll > table { margin-bottom: 0; width: 100%; min-width: min-content; }
/* The header row stays on one line. Body cells wrap, so a table scrolls only
   when its min-content width really exceeds the measure. The wide table in the
   kernel-contribution post has a full sentence in its first column: nowrap
   there would make it about twice the reading measure and force a sideways
   scroll to read every row, which is worse than the Pico version. */
.tty-scroll > table thead th { white-space: nowrap; }

/* List markers. `▪` (U+25AA), `○` (U+25CB) and `●` (U+25CF) are Geometric
   Shapes. tokens/fonts.css loads only the latin subset of JetBrains Mono, so
   none of the three is in the web font, and `--font-glyph` alone hands them to
   an unknown system face at an unknown advance and cap height. No web font is
   added: the output stays static files with no new runtime dependency. Instead
   the stack names the faces that do carry the block, and the marker gets a
   fixed one-character cell so a fallback advance cannot push it off the grid. */
.tty-prose {
  --font-marker: "JetBrains Mono", "DejaVu Sans Mono", "Noto Sans Symbols 2",
    "Segoe UI Symbol", "Apple Symbols", ui-monospace, monospace;
}
.tty-prose ul > li::before {
  font-family: var(--font-marker);
  font-size: 0.85em;
  line-height: var(--leading-body);
  width: 1ch;
  text-align: center;
}

/* Task list items. The `[ ]` text is already stripped by the tty_task_glyphs
   rule, so these only replace the default block marker, and they inherit the
   face and the cell from the rule above. Both glyphs are in the design system's
   vocabulary. Order matters: --on has the same specificity as .tty-task, so it
   must come second to win. */
.tty-prose ul > li.tty-task::before { content: "○"; color: var(--text-muted); }
.tty-prose ul > li.tty-task--on::before { content: "●"; color: var(--yellow); }

/* Figure captions.
   The attribute selectors match the inline-styled blocks already written into
   the posts, so no post has to be edited. New posts should use the classes:
   <div class="tty-figure"> … </div> and <p class="tty-caption">…</p>. */
.tty-prose .tty-figure,
.tty-prose div[style*="justify-content: center"] {
  display: flex;
  justify-content: center;
  margin: var(--sp-8) 0 0;
}
.tty-prose .tty-figure img,
.tty-prose div[style*="justify-content: center"] img { margin: 0; }

.tty-prose .tty-caption,
.tty-prose p[style*="text-align: center"] {
  max-width: var(--measure-prose);
  margin: var(--sp-3) auto var(--sp-8);
  font-size: var(--text-sm);
  line-height: 1.6;
  color: var(--text-faint);
  text-align: center;
  text-wrap: pretty;
}
.tty-prose .tty-caption em,
.tty-prose p[style*="text-align: center"] em { font-style: normal; }

/* The figure breakout is NOT here. Task 4 puts it in content.css, next to the
   .tty-prose measure it overrides, using `position: relative` and a negative
   `left`. Do not add a second implementation: this file is imported after
   content.css at equal specificity, so a `margin-left`/`transform` version
   would stack on top of the `left` offset, push every figure off centre, and
   clip it on the right. The rules above set `display`, `margin` and the caption
   only, which the Task 4 rules never touch. */
```

The caption rule drops the italic, because the whole caption is already set apart by size
and colour, and the posts wrap every caption in `<em>` purely to make it look like a caption.

The figure bleed stops below 1280px, where the column already is the page. 92ch is about
938px, and `.tty-main` is 1240px wide minus two 28px gutters, so a bled figure always fits
inside the shell and `overflow-x: hidden` never clips it. The captions stay at the text
measure: a caption is prose.

- [ ] **Step 5: Run the check to verify it passes**

Run: `bun run build && ./scripts/check-build.sh`
Expected: PASS — `check-build: all assertions passed`

- [ ] **Step 6: Read the three affected posts**

Run: `bun run start`. Open each and check the specific thing:

1. `http://localhost:8080/posts/notes-on-the-contribution-for-the-linux-kernel/` — find the
   four-column table. At a 1440px viewport it must fit inside the column with its body cells
   wrapped, and it must not scroll sideways. Then narrow the window until it can no longer
   fit: a scrollbar must appear on the table itself, and dragging it must reach the
   `Stale for` column. The page must never scroll sideways.
2. `http://localhost:8080/posts/how-to-succeed-in-ai-assisted-coding-interviews/` — find the
   checklist. Each item shows one `○`, not `▪ [ ]`, and the glyph sits on the first text line
   of the item at the same size as the bullets in the ordinary lists above it. No checkbox is
   clickable, because none exists. Check the glyph on a second platform if you have one: it
   comes from a font fallback, so that is where it can move.
3. `http://localhost:8080/posts/measuring-corporate-knowledge-concentration-in-the-linux-kernel/`
   — the plots are centred in a 1px frame and wider than the text column. At a 1440px
   viewport the four-panel plot must be at least 900px wide and every panel's axis labels
   must be readable. Each caption below is small, grey, centred and upright, clearly not body
   copy, and stays at the text measure.

Narrow the window to 380px and re-check the table post and the plot post: the table scrolls
inside its own box, the figures fill the column, and there is no horizontal page scroll on
either. Stop the server before you run the check again.

- [ ] **Step 7: Write a scratch post to prove the authoring path**

The point of this task is that Markdown stays the whole interface. Prove it. Create
`src/en/posts/_scratch.md`:

````markdown
---
title: "Scratch"
date: 2026-09-21
layout: layouts/post.njk
language: en
place: brazil
description: "A throwaway post that exercises every Markdown feature this site renders."
tags:
  - scratch
---

Ordinary prose with a [link](https://example.com), `inline code`, **bold** and _italic_.

## A heading in the display face

### A heading one level down

- a list item
- another, with `code` in it
  - and a nested item

1. a numbered item
2. another

- [ ] an open task
- [x] a done task

> A quote that should carry a yellow bar.

| column | another | a third |
| --- | --- | --- |
| a value | a longer value that pushes the table out | and one more so it has to scroll somewhere |

```python
def hello(name: str) -> str:
    return f"hello {name}"
```

Inline maths $E = mc^2$ and a display block:

$$\sum_{i=1}^{n} x_i = 1$$

![a figure](/og-image.png)

<p class="tty-caption">A caption written with the class rather than an inline style.</p>
````

Run `bun run start` and open `http://localhost:8080/posts/_scratch/`. The dev server builds
and watches, so it picks the new file up by itself. Do not run `bun run build` while it is
up: both write into `dist/` and they fight. Every element must render correctly. That is the
whole authoring contract: one `.md` file, frontmatter, no HTML required.

Then stop the server and delete the probe — it was never a post:

```bash
rm src/en/posts/_scratch.md
```

Run `bun run clean && bun run build && ./scripts/check-build.sh` once more and expect PASS,
so no trace of the scratch post reaches `dist/`, the feed, the sitemap or the search index.

- [ ] **Step 8: Commit**

```bash
git add .eleventy.js src/styles/tty/prose.css scripts/check-build.sh
git commit -m "fix(prose): handle the Markdown these posts actually contain

Four problems the design system introduced or exposed:

The vendored tokens end with 'html, body { overflow-x: hidden }', which clipped
the four-column table in the kernel-contribution post instead of scrolling it.
Every Markdown table now renders inside its own scroll container. The cells
still wrap, so that table fits at desktop and scrolls only when it must: its
first column is a full sentence, and nowrap would double the reading measure.

Task 6's block list marker collided with task lists, which markdown-it leaves
as a literal '[ ]' in the text, so items read '▪ [ ] ...'. A markdown-it core
rule strips the prefix and marks the item, and CSS draws ○ or ●. The rule reads
the <li> two tokens back from the inline token, because markdown-it always puts
a paragraph between them, hidden in a tight list. No checkbox element is
emitted — a disabled control on a static page is dead furniture.

The three marker glyphs are Geometric Shapes and the tokens load only the latin
subset of JetBrains Mono, so they came from an unknown system face. They keep a
named fallback stack and a fixed one-character cell instead of a new web font.

The 13 centred figure captions already written into the posts were rendering at
body size in body colour. They are matched by attribute selector, so no post
needed editing, and .tty-caption is there for new ones. The figures themselves
may now bleed to the 92ch wide measure at desktop, so the multi-panel plots
stay as readable as they are today instead of shrinking to 68ch.

No new package: three markdown-it rules and CSS. Markdown stays the only thing
an author has to write."
```

---

## Self-Review

Run through this after the last task, before you tell the owner it is done.

**1. Every answer the owner gave is implemented.**

| Decision | Where |
|---|---|
| Wordmark is `ELLIANCARLOS_` | Task 5, `nav.njk` |
| Pico CSS removed completely | Tasks 5 and 16 |
| `/posts/` excludes archived posts | Task 7, `postsActive_en` |
| `/posts/archive/` is the full index | Task 11 |
| `/preprints/` is one list, PDF in a new tab | Task 13 |

**2. Every design system screen has a home.** About → `/` (Task 14). Home → `/posts/`
(Task 10). Archive → `/posts/archive/` (Task 11). Post → post layout (Task 8). Site shell
→ `layout.njk`, `nav.njk`, `footer.njk`, `searchOverlay.njk` (Tasks 5 and 9).

**3. The output needs no backend.** The harness proves it on every build: the `no backend`
section added in Task 1 walks the tree with
`grep -rliF --include='*.html' -e '<form' -e 'action=' -e 'method="post"'` and finds
nothing, and it fails if `dist/_redirects` or `dist/netlify.toml` appears. Do not check this
by hand with `dist/**/*.html`: `bash` does not expand `**` recursively without
`shopt -s globstar`, so that glob reads `dist/*/*.html` and never sees `dist/index.html`,
`dist/404.html` or any post. One `<input>` ships — the search field — and it posts nowhere.
One `fetch()` runs, against `/search-index-en.json`, which the build writes. The design
system's newsletter block is replaced by the site's own feed links. `dist/` is servable by
any static host.

**4. Markdown is still the whole authoring interface.** A post is one `.md` file with
frontmatter. The only key this migration adds is the optional `archived: true`, and
`CLAUDE.md`'s frontmatter block now lists it. No task asks an author to write HTML, a macro
or a component. Task 17's scratch-post step proves every Markdown feature the posts use
renders: headings, nested lists, task lists, quotes, wide tables, fenced code, inline and
display maths, figures and captions.

Two of those depend on build-time `markdown-it` rules, so check them in the output and not
by reading the code: `dist/posts/how-to-succeed-in-ai-assisted-coding-interviews/index.html`
must hold `<li class="tty-task tty-task--off">` and no literal `[ ]`, and
`dist/posts/notes-on-the-contribution-for-the-linux-kernel/index.html` must hold
`<div class="tty-scroll"><table>`. `check-build.sh` asserts both. One documented limit: a
task item in an *ordered* list keeps its literal `[ ]`, because the marker CSS is scoped to
`ul > li`. No post uses that form.

**5. Every URL that existed before still exists.** `/`, `/posts/`, every
`/posts/<slug>/`, every `/posts/tag/<slug>/`, `/contact/`, `/404.html`, `/feed.xml`,
`/sitemap.xml`, `/llms.txt`, `/search-index-en.json`, `/robots.txt`, `/_headers`,
`/Ellian_Carlos_Resume.pdf`. Two URLs are new: `/posts/archive/` and `/preprints/`.
`check-build.sh` asserts on all of them.

**6. Name consistency.** Every class a macro emits is defined in `core.css`,
`content.css` or `layout.css`. Every filter a template calls is registered in
`.eleventy.js`: `postDate`, `tagSlug`, `json`, `filterByTag`, `i18nUrl`, `switchLanguage`
(pre-existing), plus `readingTime`, `groupByYear`, `postIndexes`, `nextPost` (Task 7),
`plural` (Task 10, called by Tasks 11, 12 and 13) and `pad3` (Task 13). Every DOM id and `data-` hook a script reads is declared in the task that
produces the markup.

**7. Ask the owner these five.** None of them blocks the migration.

- `src/en/posts/my-tools-2024.md` now carries `archived: true`. Keep it, or move the flag?
- `src/en/contact.njk` still shows `elliancarlos@example.com`. Should it be the real
  address?
- The corporate truck factor paper has `venue: "preprint"`. Is there a venue, a submission
  status, or a DOI to record?
- The biography reads "I am learning Rust continously!". Correct the spelling to
  "continuously"? It is the owner's sentence, so it is the owner's call.
- `structuredData.njk` still claims `knowsLanguage: ["en","pt","es","ja"]` while i18n is
  off, and `pt.json`, `es.json` and `ja.json` did not get the new UI keys. Both matter only
  if `I18N_ENABLED` flips back on.

The two exclamation marks in the biography are not on that list, and they are not a defect.
The design system's "no exclamation marks" rule governs UI strings — labels, hints, empty
states, button text. The biography is the owner's own writing. Leave it alone.

**8. This plan was audited.** Six independent lenses read it: static output and R2, Markdown
fidelity and R1, the design system port, copy and voice, the Nunjucks and Eleventy layer,
and task-by-task executability. Twenty-seven corrections came out of that audit for Tasks 14
to 17, the Self-Review and the Execution Handoff. Four of them would have stopped a task
going green: a `markdown-it` rule that could never fire, an emoji check that could never
fail, a verification step that could not be performed, and a homepage rewrite that dropped a
paragraph of the owner's prose. The earlier tasks carry their own corrections from the same
audit.

---

## Execution Handoff

Plan complete and saved to
`docs/superpowers/plans/2026-09-21-tty-design-system-migration.md`.

Seventeen tasks. Each one ends with a green
`bun run build && ./scripts/check-build.sh` and its own commit, so a reviewer can accept or
reject any single task without unpicking its neighbours.

The order matters in seven places:

1. Task 2 before every other styling task — the tokens come first.
2. Task 5 before Tasks 8 to 15 — it owns the page shell and the complete `en.json`, and
   every later screen reads a key from it.
3. Task 6 before Task 8 — the post page has nothing to style until `prose.css` exists.
4. Task 7 before Tasks 8, 10, 11, 12 and 14 — they call `readingTime`, `postIndexes`,
   `groupByYear` and `nextPost`.
5. Task 9 before Task 10 — the `/` overlay has to work before the in-content search box
   comes off `/posts/`, or search breaks for one commit.
6. Task 11 before Tasks 10, 12 and 13 — they link `/posts/archive/`, and Task 10 asserts on
   that link, so the archive page must exist first.
7. Task 8 before Task 17 — every rule in Task 17 is scoped to `.tty-prose`, and Task 8 is
   what wraps the post body in it. Do not pull Task 17 forward to Task 6: three of its four
   visual checks then fail for a reason that has nothing to do with the task.

One order that satisfies all seven: 1, 2, 3, 4, 5, 6, 7, 9, 11, 8, 17, 10, 12, 13, 14, 15,
16.

Tasks 12, 13, 14 and 15 are independent of each other and can run in any order among
themselves. Task 16 runs last: it deletes what the other tasks stopped using.

Two execution options:

**1. Subagent-Driven (recommended)** — a fresh subagent per task, review between tasks,
fast iteration.

**2. Inline Execution** — execute the tasks in this session using
`superpowers:executing-plans`, batch execution with checkpoints for review.

Which approach?
