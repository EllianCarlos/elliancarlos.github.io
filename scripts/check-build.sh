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

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'check-build: all assertions passed\n'
  exit 0
fi
printf 'check-build: %s assertion(s) failed\n' "$fails"
exit 1
