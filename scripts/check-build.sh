#!/usr/bin/env bash
# Asserts on an existing dist/ tree. This script never builds.
# Run `bun run build` first, then run this.
#
# Warning: `bun run build` writes into dist/. Stop the dev server
# (`bun run start`) before you build, or the two fight over dist/.

set -uo pipefail

DIST="${DIST:-dist}"
fails=0
passes=0

# The suite's own tripwire (I8): a dropped, renamed or mistyped assertion call
# must not vanish silently. EXPECTED_ASSERTIONS is the total `passes + fails`
# this script produces today, counted (not guessed) after every change to the
# assertion list. See the check at the bottom of the file.
EXPECTED_ASSERTIONS=243

pass() { printf '  ok   %s\n' "$1"; passes=$((passes + 1)); }
bad()  { printf '  FAIL %s\n' "$1"; fails=$((fails + 1)); }

section() { printf '\n== %s\n' "$1"; }

have() {
  if [ -f "$DIST/$1" ]; then pass "file $1"; else bad "file $1 is missing"; fi
}

# grep exit status: 0 = match found, 1 = no match (genuinely absent), 2 = error
# (e.g. unreadable file). `if grep ...; then ... else ... fi` cannot tell 1
# apart from 2, so an unreadable file used to read as "absent" — which made a
# grep_not assertion PASS on an error. Capture the real status instead.
grep_in() {
  if [ ! -f "$DIST/$1" ]; then bad "$3 (file $1 is missing)"; return; fi
  grep -qF -e "$2" "$DIST/$1"
  case $? in
    0) pass "$3" ;;
    1) bad "$3" ;;
    *) bad "$3 (grep error reading $1)" ;;
  esac
}

grep_not() {
  if [ ! -f "$DIST/$1" ]; then bad "$3 (file $1 is missing)"; return; fi
  grep -qF -e "$2" "$DIST/$1"
  case $? in
    0) bad "$3" ;;
    1) pass "$3" ;;
    *) bad "$3 (grep error reading $1)" ;;
  esac
}

count_at_least() {
  if [ ! -f "$DIST/$1" ]; then bad "$4 (file $1 is missing)"; return; fi
  n=$(grep -oF -e "$2" "$DIST/$1" | wc -l || true)
  if [ "$n" -ge "$3" ]; then pass "$4 ($n found)"; else bad "$4 (found $n, want $3+)"; fi
}

count_exactly() {
  if [ ! -f "$DIST/$1" ]; then bad "$4 (file $1 is missing)"; return; fi
  n=$(grep -oF -e "$2" "$DIST/$1" | wc -l || true)
  if [ "$n" -eq "$3" ]; then pass "$4 ($n found)"; else bad "$4 (found $n, want exactly $3)"; fi
}

absent() {
  if [ -e "$DIST/$1" ]; then bad "$2 ($1 is present)"; else pass "$2"; fi
}

# I3: three ordinary authoring actions used to turn CI red, because these
# assertions pinned a content count (13 active posts, "1 post", "1 paper")
# instead of testing the grammar rule that produces that text. This derives
# both the count AND the expected word (singular/plural, from the `plural`
# filter's own convention: exactly 1 -> singular) from the built page itself,
# so it stays correct as posts are archived or added, forever — not just at
# today's counts.
plural_count_assert() {
  # $1 = file  $2 = row-class needle  $3 = singular word  $4 = plural word  $5 = label
  if [ ! -f "$DIST/$1" ]; then bad "$5 (file $1 is missing)"; return; fi
  n=$(grep -oF -e "$2" "$DIST/$1" | wc -l || true)
  word="$4"
  if [ "$n" -eq 1 ]; then word="$3"; fi
  grep_in "$1" "${n} ${word}</span>" "$5 ($n $word)"
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
# webfonts.css can, by construction, never contain "@latest" — it is the
# pinned override. dist/styles/tty/tokens/fonts.css (vendored, unedited) SHIPS
# silkscreen@latest twice; the site is only correct because tty.css imports
# tokens/fonts.css before webfonts.css, so two identical @font-face rules
# resolve to the last one declared and the pin wins. Test that ordering
# invariant directly instead of grepping the wrong file for a string it can
# never hold.
fonts_import_line=$(grep -n -F '@import "tty/tokens/fonts.css"' "$DIST/styles/tty.css" | head -1 | cut -d: -f1)
webfonts_import_line=$(grep -n -F '@import "tty/webfonts.css"' "$DIST/styles/tty.css" | head -1 | cut -d: -f1)
if [ -n "${fonts_import_line:-}" ] && [ -n "${webfonts_import_line:-}" ] \
  && [ "$fonts_import_line" -lt "$webfonts_import_line" ]; then
  pass "tty.css imports tokens/fonts.css before webfonts.css, so the pinned rule wins"
else
  bad "tty.css imports tokens/fonts.css before webfonts.css, so the pinned rule wins"
fi

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
grep_in "index.html" 'href="/preprints/"' "the nav tab for preprints opens once the page exists"
grep_in "index.html" 'data-tty-search-open hidden' "the search control stays hidden until a script can open it"
grep_in "index.html" 'class="tty-foot"' "the new footer is present"
grep_in "posts/index.html" 'aria-current="page"' "the active tab is marked on /posts/"
grep_in "index.html" 'content="#0A0A09"' "the theme colour is the root surface"
grep_not "index.html" "mobile-menu-toggle" "the old hamburger is gone"
grep_not "index.html" "page-header-content" "the old page header is gone"

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

grep_in "posts/how-to-setup-lkd-notes/index.html" 'class="language-' "the post still ships highlighted code"
grep_not "posts/how-to-setup-lkd-notes/index.html" "prism-toolbar.min.css" "the CDN toolbar stylesheet is gone"
grep_in "posts/how-to-setup-lkd-notes/index.html" "prism-toolbar.min.js" "the toolbar script is still injected"

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
# Carried finding from Task 5's review: /posts/ and /posts/archive/ are both
# live nav tabs, and /posts/archive/ is a URL prefix match for both. nav.njk
# must pick the longest matching prefix so only one tab carries
# aria-current="page" here — two would be an invalid ARIA state.
count_exactly "posts/archive/index.html" 'aria-current="page"' 1 "exactly one nav tab is current on the archive page"

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

section "posts landing page"
have "scripts/tty-typewriter.js"
grep_in "posts/index.html" 'tty-h1--hero' "the hero title is present"
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
# I3: was pinned to 13, which failed CI the moment a second post was
# archived. Derive the expected active count from the build itself instead:
# every post page under posts/ (excluding the index, archive and tag
# listings) minus however many of those carry the archived banner (the same
# signal "the archived post shows a banner" trusts, in the post page section
# below).
all_post_pages=$(find "$DIST/posts" -mindepth 2 -maxdepth 2 -name index.html \
  ! -path "$DIST/posts/archive/index.html" 2>/dev/null)
total_posts=$(printf '%s\n' "$all_post_pages" | grep -c . || true)
archived_posts=0
if [ -n "$all_post_pages" ]; then
  archived_posts=$(grep -lF 'class="tty-note tty-note--warn"' $all_post_pages 2>/dev/null | grep -c . || true)
fi
expected_active=$((total_posts - archived_posts))
count_exactly "posts/index.html" 'class="tty-postrow"' "$expected_active" \
  "every active post is listed ($expected_active active of $total_posts total)"

section "tag pages"
have "posts/tag/linux/index.html"
grep_in "posts/tag/linux/index.html" 'class="tty-postrow"' "tag pages use the design system row"
grep_in "posts/tag/linux/index.html" 'class="tty-archive__head"' "tag pages reuse the archive head"
grep_in "posts/tag/linux/index.html" "/posts/archive/" "a tag page links back to the archive"
# I3: was pinned to the exact string "1 post", which failed CI the moment a
# second japanese-tagged post was written. Derive both the count and the
# expected singular/plural word from the page itself instead.
plural_count_assert "posts/tag/japanese/index.html" 'class="tty-postrow"' "post" "posts" \
  "the japanese tag page's count uses correct singular/plural grammar"
grep_not "posts/tag/linux/index.html" 'class="tag-pill"' "the old tag pills are gone"
grep_not "posts/tag/linux/index.html" '<h2 class="blog">' "the old Pico headings are gone"

section "preprints"
have "preprints/index.html"
have "preprints/Corporate_Truck_Factor__Firm_Level_Knowledge_Concentration_in_Linux_Kernel_Subsystems.pdf"
grep_in "preprints/index.html" "Corporate Truck Factor" "the paper title is listed"
grep_in "preprints/index.html" "Paulo Meirelles" "the author list is listed"
grep_in "preprints/index.html" 'target="_blank"' "the row opens in a new tab"
grep_in "preprints/index.html" 'rel="noreferrer noopener"' "the new tab is opened safely"
grep_in "preprints/index.html" ".pdf" "the row links a PDF"
grep_in "preprints/index.html" 'class="tty-paper"' "the paper row renders"
# I3: was pinned to the exact string "1 paper", which failed CI the moment a
# second preprint was added — a two-step authoring action preprints.js itself
# documents. Derive both the count and the expected singular/plural word.
plural_count_assert "preprints/index.html" 'class="tty-paper"' "paper" "papers" \
  "the preprints count uses correct singular/plural grammar"
grep_in "preprints/index.html" 'aria-current="page"' "the preprints tab is marked active"
grep_in "llms.txt" "/preprints/" "llms.txt points at the preprints page"
grep_in "styles/tty/layout.css" ".tty-paper__title" "the paper row CSS is present"

section "homepage"
grep_in "index.html" 'class="tty-prose"' "the biography is inside the prose wrapper"
grep_in "index.html" 'class="tty-term"' "the whoami terminal is present"
grep_in "index.html" 'class="tty-linklist"' "the elsewhere list is present"
# L17: 'class="tty-menu' alone is satisfied by the search overlay's
# <ul class="tty-menu" id="tty-search-results"> (searchOverlay.njk), which
# ships hidden on every page. Deleting the homepage's entire recent rail left
# this green. Key the needle to the rail's own modifier class instead.
grep_in "index.html" 'class="tty-menu tty-menu--dense"' "the recent rail is present"
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

# The resume and the academic cv are asserted through their `tty-linklist` rows, not through
# their URLs. Task 5's footer already carries both URLs, so a URL assertion here would pass
# before this task writes a line of markup.

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

section "contact and error pages"
have "contact/index.html"
grep_in "contact/index.html" 'class="tty-linklist"' "contact uses the key/value list"
grep_in "contact/index.html" 'class="tty-h1"' "contact has a display title"
# L17 (same shape as the recent-rail fix above): searchOverlay.njk's
# <ul class="tty-menu" id="tty-search-results"> ships on every page, so a
# check keyed on bare "<ul>" is only correct today because that element
# happens to carry a class. The old Pico contact markup was an unclassed
# <ul><li>...</li></ul>; key the needle to "<li>" instead — the search
# overlay never emits a static <li> (its rows are written by JS at runtime)
# — so this stops depending on an accident of a shared, unrelated partial.
grep_not "contact/index.html" "<li>" "the old plain list is gone from contact"
grep_in "404.html" 'class="tty-h1"' "the 404 page has a display title"
grep_in "404.html" 'class="tty-btn' "the 404 page offers a way home"
grep_not "404.html" "language-select" "the dead language selector script is gone"
grep_not "404.html" "page-header-content" "the dead page header lookup is gone"
grep_in "404.html" "strippedPath" "the language-prefix redirect survives"
# I2: id="error-404" is the sole guard in languageRedirect.njk against the
# documented /pt/pt/pt/... redirect loop on an untranslated 404. It is inert
# while i18n is disabled, but it must not silently disappear again.
grep_in "404.html" 'id="error-404"' "the redirect-loop guard id survives on the 404 page"

section "dead code is gone"
if [ -f "$DIST/styles/style.css" ]; then bad "styles/style.css is deleted"; else pass "styles/style.css is deleted"; fi
if [ -f "$DIST/styles/blog.css" ]; then bad "styles/blog.css is deleted"; else pass "styles/blog.css is deleted"; fi
if [ -f "$DIST/scripts/search.js" ]; then bad "scripts/search.js is deleted"; else pass "scripts/search.js is deleted"; fi
have "scripts/tty-search.js"
have "scripts/tty-progress.js"
have "scripts/tty-typewriter.js"
have "scripts/tty-archive.js"

printf '\n'

# I8: the tripwire. Without this, a dropped, renamed or mistyped assertion
# call site vanishes with no signal — the suite still exits 0 and still
# prints "all assertions passed", just with a smaller `ok` count nobody is
# watching. This turns "fewer assertions ran than expected" into a hard,
# loud failure on its own.
total=$((passes + fails))
if [ "$total" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf 'FAIL: expected %s assertions to run, but %s ran (passes=%s fails=%s)\n' \
    "$EXPECTED_ASSERTIONS" "$total" "$passes" "$fails"
  printf 'A section, a call site, or a whole assertion silently disappeared (or one was added\n'
  printf 'without updating EXPECTED_ASSERTIONS at the top of this file).\n'
  fails=$((fails + 1))
fi

if [ "$fails" -eq 0 ]; then
  printf 'check-build: all %s assertions passed\n' "$passes"
  exit 0
fi
printf 'check-build: %s assertion(s) failed\n' "$fails"
exit 1
