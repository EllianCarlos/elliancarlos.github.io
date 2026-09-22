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
grep_not "styles/tty/webfonts.css" "@latest" "no mutable font tag ships"

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
grep_not "index.html" 'href="/preprints/"' "the nav ships no tab for a page the build does not write"
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

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'check-build: all assertions passed\n'
  exit 0
fi
printf 'check-build: %s assertion(s) failed\n' "$fails"
exit 1
