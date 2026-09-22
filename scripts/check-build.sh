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
EXPECTED_ASSERTIONS=323

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
# assertions pinned a content count (13 posts, "1 post", "1 paper") instead of
# testing the grammar rule that produces that text. This derives both the count
# AND the expected word (singular/plural, from the `plural` filter's own
# convention: exactly 1 -> singular) from the built page itself, so it stays
# correct as posts and papers are added, forever — not just at today's counts.
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

# sitemap.xml is the only complete list of this site's URLs a crawler reads, so
# every URL in it must be a page the build wrote, and every page the build
# writes belongs in it. Both halves used to be wrong for tag pages:
# src/tag/index.njk is paginated, and the sitemap plugin rewrites a paginated
# item's URL from `pagination.hrefs`, which never sees the computed permalink in
# src/tag/tag.11tydata.js. One `/tag/` entry — a path the build never writes —
# stood in for all the real /posts/tag/<slug>/ pages, and none of those appeared.
#
# No tag name and no count is written down here. Both sides of the comparison
# are read out of the build, so writing a post with a brand-new tag can never
# turn CI red — that was finding I3.
section "sitemap coverage"
# "/tag/</loc>" matches only a loc that ENDS in /tag/, which is the bad entry: a
# real tag page's loc ends in its slug (".../posts/tag/linux/</loc>"), so it
# cannot match. The needle carries no hostname either, so changing the sitemap
# hostname in .eleventy.js cannot quietly make this assertion vacuous.
grep_not "sitemap.xml" "/tag/</loc>" "the 404 /tag/ URL is not in the sitemap"
count_at_least "sitemap.xml" "/posts/tag/" 1 "the sitemap lists tag pages"
# One tag slug per line, from each side of the contract: the pages the build
# actually wrote, and the URLs the sitemap advertises.
built_tag_slugs=$(find "$DIST/posts/tag" -mindepth 2 -maxdepth 2 -name index.html 2>/dev/null \
  | sed -E 's|.*/posts/tag/([^/]+)/index\.html$|\1|' | sort)
sitemap_tag_slugs=$(grep -oE '<loc>[^<]*/posts/tag/[^/]+/</loc>' "$DIST/sitemap.xml" 2>/dev/null \
  | sed -E 's|.*/posts/tag/([^/]+)/</loc>|\1|' | sort)
built_tag_pages=$(printf '%s\n' "$built_tag_slugs" | grep -c . || true)
count_exactly "sitemap.xml" "/posts/tag/" "$built_tag_pages" \
  "every tag page the build wrote is in the sitemap ($built_tag_pages pages)"
# The count alone cannot see a wrong URL, only a missing one: a slug built one
# way and advertised another keeps both sides at the same total. Compare the
# sets, so the sitemap has to name the directories the build really wrote.
if [ "$built_tag_slugs" = "$sitemap_tag_slugs" ]; then
  pass "the sitemap's tag URLs are the tag pages on disk, slug for slug"
else
  bad "the sitemap's tag URLs are the tag pages on disk, slug for slug"
fi

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

section "data files are not pages"
# sitemap.njk renders the whole of collections.all, so any template that forgets
# `eleventyExcludeFromCollections: true` is advertised to crawlers as a page.
# search-index.njk forgot it, and the sitemap listed the search index JSON.
# The first assertion names that one file; the second is the general rule, and
# catches the next data file to repeat the mistake. The sitemap is pretty-printed
# by a transform that only breaks lines between `><`, so a <loc> stays on one
# line and a fixed-string match is sound.
grep_not "sitemap.xml" "search-index" "the sitemap does not list the search index"
grep_not "sitemap.xml" ".json</loc>" "the sitemap lists no .json file as a page"

section "icons and social thumbnails"
# The icons and thumbnails are committed assets, generated by `bun run images`
# (scripts/make-images.mjs). Nothing here shells out to ImageMagick: CI's build job
# is a bare ubuntu-latest image and the devenv job declares only `git`, so this
# script must read PNGs with the tools a plain shell has. PNG stores width and
# height as two big-endian 32-bit integers at byte 16 of the IHDR chunk, which perl
# can unpack without any image library.
png_size() {
  perl -e 'open my $f, "<:raw", $ARGV[0] or exit 1; read $f, my $b, 24;
           my ($w, $h) = unpack "N2", substr($b, 16, 8); print "${w}x${h}"' "$1" 2>/dev/null
}
icon_dims() {
  # $1 = file under dist/  $2 = expected WxH
  if [ ! -f "$DIST/$1" ]; then bad "icon $1 exists at $2 (missing)"; return; fi
  got=$(png_size "$DIST/$1")
  if [ "$got" = "$2" ]; then pass "icon $1 is $2"; else bad "icon $1 is $2 (got ${got:-unreadable})"; fi
}
icon_dims "favicon-16x16.png" "16x16"
icon_dims "favicon-32x32.png" "32x32"
icon_dims "apple-touch-icon.png" "180x180"
icon_dims "icon-512.png" "512x512"
# Every icon the head advertises must be served from the site ROOT. Adding a file to
# public/ is not enough: addPassthroughCopy("public") lands that whole directory at
# dist/public/, so an icon needs its own explicit mapping in .eleventy.js. Reading
# the hrefs back out of the page is what catches a link added without the mapping.
missing_icon=""
icon_n=0
while IFS= read -r href; do
  [ -n "$href" ] || continue
  icon_n=$((icon_n + 1))
  [ -f "$DIST/$href" ] || missing_icon="$missing_icon /$href"
done <<EOF
$(grep -oE '<link rel="(icon|apple-touch-icon)"[^>]*href="/[^"]*"' "$DIST/index.html" \
  | sed -E 's|.*href="/([^"]*)".*|\1|' | sort -u)
EOF
if [ "$icon_n" -gt 0 ] && [ -z "$missing_icon" ]; then
  pass "every icon the head links is served from the site root ($icon_n icons)"
else
  bad "every icon the head links is served from the site root (missing:${missing_icon:-none checked})"
fi

# 1200x630 is the Open Graph box every scraper crops to, and the size budget is the
# reason this section exists at all: the image this replaced was 2848x1504 and
# 5.1 MB, over the ceiling several scrapers enforce, so it may not have rendered at
# all on some platforms. 400 KB is generous for flat-colour PNGs that currently
# come in near 100 KB, and it is far below any platform limit.
OG_MAX_KB=400
og_ok() {
  if [ ! -f "$DIST/$1" ]; then bad "thumbnail $1 is 1200x630 and under ${OG_MAX_KB}KB (missing)"; return; fi
  got=$(png_size "$DIST/$1")
  kb=$(( $(wc -c < "$DIST/$1") / 1024 ))
  if [ "$got" = "1200x630" ] && [ "$kb" -le "$OG_MAX_KB" ]; then
    pass "thumbnail $1 is 1200x630 and ${kb}KB"
  else
    bad "thumbnail $1 is 1200x630 and under ${OG_MAX_KB}KB (got ${got:-unreadable}, ${kb}KB)"
  fi
}
og_ok "og-image.png"

# Every thumbnail, not just the default — one oversized file is enough to break the
# preview on the page that ships it. Both the geometry and the budget are checked
# per file, and the list is read off disk so a new post's thumbnail is covered the
# moment it is generated.
og_bad=""
for f in "$DIST"/og/*.png; do
  [ -f "$f" ] || continue
  d=$(png_size "$f")
  k=$(( $(wc -c < "$f") / 1024 ))
  if [ "$d" != "1200x630" ] || [ "$k" -gt "$OG_MAX_KB" ]; then
    og_bad="$og_bad $(basename "$f")(${d:-?},${k}KB)"
  fi
done
og_n=$(find "$DIST/og" -name '*.png' 2>/dev/null | wc -l)
if [ "$og_n" -gt 0 ] && [ -z "$og_bad" ]; then
  pass "every post thumbnail is 1200x630 and under ${OG_MAX_KB}KB ($og_n files)"
else
  bad "every post thumbnail is 1200x630 and under ${OG_MAX_KB}KB (${og_bad:-none found})"
fi

# The assertion that makes the committed-asset design safe. og:image is an absolute
# URL, so strip the hostname and check the path exists in the build. A post with no
# generated thumbnail falls back to the site default, which exists — so WRITING a
# post never turns CI red, while a typo in posts.11tydata.js or a deleted file
# always does.
missing_og=""
checked_og=0
while IFS= read -r url; do
  rel=${url#https://elliancarlos.com.br}
  checked_og=$((checked_og + 1))
  [ -f "$DIST$rel" ] || missing_og="$missing_og $rel"
done <<EOF
$(grep -rhoE '<meta property="og:image" content="[^"]*"' --include='*.html' "$DIST" \
  | sed -E 's/.*content="([^"]*)".*/\1/' | sort -u)
EOF
if [ "$checked_og" -gt 0 ] && [ -z "$missing_og" ]; then
  pass "every og:image the site advertises exists in the build ($checked_og distinct)"
else
  bad "every og:image the site advertises exists in the build (missing:${missing_og:-none checked})"
fi

# A scraper that reads twitter:image instead of og:image must get the same picture.
# Both tags come from the same variable, so this guards the template, not the data.
og_urls=$(grep -rhoE '<meta property="og:image" content="[^"]*"' --include='*.html' "$DIST" \
  | sed -E 's/.*content="([^"]*)".*/\1/' | sort -u)
tw_urls=$(grep -rhoE '<meta name="twitter:image" content="[^"]*"' --include='*.html' "$DIST" \
  | sed -E 's/.*content="([^"]*)".*/\1/' | sort -u)
if [ -n "$og_urls" ] && [ "$og_urls" = "$tw_urls" ]; then
  pass "twitter:image advertises the same images as og:image"
else
  bad "twitter:image advertises the same images as og:image"
fi

# At least one post page must carry its OWN thumbnail, or posts.11tydata.js has
# silently stopped resolving and every share falls back to the site default. Counted
# across all post pages rather than naming one: naming a slug would turn CI red the
# day that post is renamed, which is finding I3.
own_og=$(grep -rlE '<meta property="og:image" content="[^"]*/og/[^"]*"' \
  --include='index.html' "$DIST/posts" 2>/dev/null | wc -l)
if [ "$own_og" -gt 0 ]; then
  pass "post pages advertise their own thumbnails ($own_og pages)"
else
  bad "post pages advertise their own thumbnails (none do — has \`bun run images\` been run?)"
fi

section "the contact address and the outbound PDF"
# The contact page spells its separators out in words — "[at]", "[dot]" — so there
# is no address on it in ANY reversible form. That is the whole requirement: an
# encoding is a map, and a map inverts. This page briefly used HTML numeric
# character references, which `html.unescape` undoes in one line.
#
# These assertions are therefore all negative but one, and the positive one tests
# a shape, not a string. Nothing here writes the address or the separators down, so
# the owner can rewrite either without turning CI red.
contact="contact/index.html"
grep_not "$contact" "mailto:" "the contact page carries no mailto link"
grep_not "$contact" "example.com" "the placeholder contact domain is gone"
# Numeric and hex character references are the two encodings most likely to creep
# back, because they look like a clever fix. They are not: they invert.
grep_not "$contact" "&#" "the contact page smuggles no character-reference encoding"
# The pattern demands a dot-separated domain after the @, so a bare handle such as
# "/@elliancarlos" in a profile URL cannot match it. That mattered while the page
# linked mastodon.social/@elliancarlos; it still guards the next handle-shaped URL.
if [ -f "$DIST/$contact" ] \
  && grep -qE '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z]{2,}' "$DIST/$contact"; then
  bad "no plain address survives on the contact page"
else
  pass "no plain address survives on the contact page"
fi
# Hiding the address is only half the job: the page still has to tell a reader how
# to reach the owner. `data-contact-email` is the template's own hook for that row,
# so this reads the element back out and checks two things — it says something, and
# what it says is not machine-readable. An empty row and a plain address both fail.
email_text=$(grep -oE '<span data-contact-email>[^<]*</span>' "$DIST/$contact" 2>/dev/null \
  | head -1 | sed -E 's|<[^>]*>||g' | tr -s '[:space:]' ' ' | sed -E 's/^ +| +$//g')
if [ -n "$email_text" ]; then
  pass "the contact page names a way to reach the owner"
else
  bad "the contact page names a way to reach the owner"
fi
if [ -n "$email_text" ] \
  && printf '%s' "$email_text" | grep -qE '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z]{2,}'; then
  bad "the contact row does not parse as an address (got '$email_text')"
else
  pass "the contact row does not parse as an address"
fi
# Five channels today: the address, git, work, academic cv, orcid. The mastodon row
# is gone — the owner no longer uses the account. `at_least`, so adding a channel is
# an ordinary authoring action and only losing one turns CI red.
count_at_least "$contact" 'class="tty-linklist__row"' 5 "the contact page lists every channel"
# The account is retired site-wide, not just unlinked from one page: the row, the
# footer link, the seo.social key and the sameAs entry in the JSON-LD all went. A
# leftover anywhere — including inside a schema block, which no row count can see —
# would still advertise an address the owner has abandoned.
mastodon_hits=$(grep -rliF --include='*.html' -e 'mastodon' "$DIST" | tr '\n' ' ')
if [ -n "$mastodon_hits" ]; then
  bad "no page links or names mastodon ($mastodon_hits)"
else
  pass "no page links or names mastodon"
fi
# The research curriculum is called "academic cv" on every page, from i18n
# nav.academicCv. It was briefly "lattes" on the contact page and "cv" on the
# homepage — one URL under three names. The sweep is site-wide, not per page,
# because that is the scope of the decision.
# ">lattes<" is an exact label cell, so the URL text "lattes.cnpq.br/…" cannot
# match it. Both needles name a RETIRED term, never the owner's current copy.
#
# The third needle is a different retired label on the same component: the row that
# links a GitHub account was keyed "git", and git is a version control system, not
# an account. That needle is scoped to the key cell, because "git" on its own is
# ordinary prose in several posts.
for dead_label in '>lattes<' '>cv<' 'class="tty-linklist__key">git<'; do
  dead_hits=$(grep -rlF --include='*.html' -e "$dead_label" "$DIST" | tr '\n' ' ')
  if [ -n "$dead_hits" ]; then
    bad "no page uses the retired label '$dead_label' ($dead_hits)"
  else
    pass "no page uses the retired label '$dead_label'"
  fi
done
# Every channel that leaves the site must leave it safely. Both sides are counted
# out of the page, so a new row cannot quietly skip the rel — and no URL is named,
# so the owner can change any profile link.
#
# Both counts read a NEWLINE-FLATTENED copy of the page. grep is line-based, so an
# opening tag written across two lines matches neither pattern — it drops out of
# both sides, the totals still agree, and the assertion goes vacuous for exactly
# the link it should be watching. That happened here: the footer's source link was
# split over two lines and silently escaped the check.
#
# Both link-list pages are checked, not just the contact page: the homepage carries
# the same channels in the same component, so a rule that held on one page and not
# the other would be no rule at all. This cannot widen to every page — a post body
# links outward through Markdown, which renders a bare <a> by design.
for page in "$contact" "index.html"; do
  out_links=$(tr '\n' ' ' < "$DIST/$page" \
    | grep -oE '<a href="https?://[^"]*"[^>]*>' | wc -l || true)
  out_safe=$(tr '\n' ' ' < "$DIST/$page" \
    | grep -oE '<a href="https?://[^"]*" target="_blank" rel="[^"]*noreferrer[^"]*noopener[^"]*">' \
    | wc -l || true)
  if [ "$out_links" -gt 0 ] && [ "$out_safe" -eq "$out_links" ]; then
    pass "every outbound link on /$page opens safely ($out_links links)"
  else
    bad "every outbound link on /$page opens safely ($out_safe of $out_links)"
  fi
done

# The resume PDF is linked from the header, the footer and the homepage. It used to
# open in a new tab from the header only, so the same file replaced the page from
# the other two. Both sides of each count are derived from the build, so adding a
# fourth link to the PDF cannot quietly escape the rule.
# Newline-flattened, for the reason spelled out on the outbound-contact counts
# above: a line-based grep cannot see an opening tag split across lines, and it
# would drop that tag from both counts at once.
flat_html() { find "$DIST" -name '*.html' -exec cat {} + 2>/dev/null | tr '\n' ' '; }
resume_href='href="/Ellian_Carlos_Resume.pdf"'
resume_links=$(flat_html | grep -oF -e "$resume_href" | wc -l || true)
resume_blank=$(flat_html | grep -oF -e "$resume_href target=\"_blank\"" | wc -l || true)
resume_safe=$(flat_html \
  | grep -oF -e "$resume_href target=\"_blank\" rel=\"noreferrer noopener\"" | wc -l || true)
if [ "$resume_links" -gt 0 ] && [ "$resume_blank" -eq "$resume_links" ]; then
  pass "every link to the resume opens a new tab ($resume_links links)"
else
  bad "every link to the resume opens a new tab ($resume_blank of $resume_links)"
fi
if [ "$resume_links" -gt 0 ] && [ "$resume_safe" -eq "$resume_links" ]; then
  pass "every link to the resume opens that tab safely ($resume_links links)"
else
  bad "every link to the resume opens that tab safely ($resume_safe of $resume_links)"
fi
# The flag governs collection membership, not output: the file must still be
# written, and must still hold records. Keyed to the index's own shape — the
# `url` key and the `/posts/` prefix the permalink logic produces — never to a
# post count or a title, so writing or deleting a post cannot turn this red.
count_at_least "search-index-en.json" '"url":"/posts/' 1 \
  "the search index still holds post records"
# The converse guard: over-applying the exclude flag would empty the sitemap
# rather than fix it. At least one page must still be listed.
count_at_least "sitemap.xml" "<loc>https://" 1 "the sitemap still lists pages"

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
count_at_least "index.html" 'class="tty-tabs__tab"' 5 "the four page tabs and the resume tab render"
grep_in "index.html" 'href="/preprints/"' "the nav tab for preprints opens once the page exists"
grep_in "index.html" 'data-tty-search-open hidden' "the search control stays hidden until a script can open it"
grep_in "index.html" 'class="tty-foot"' "the new footer is present"
# The footer's "elsewhere" row hand-writes a "·" between each pair of links, so the
# separators must always number one fewer than the links. Removing a link and
# forgetting its separator leaves a dangling "·"; this is how that shows up. Both
# numbers come out of the built row, so adding or dropping a link is fine as long as
# the pair stays consistent. The row is read newline-flattened, since its links wrap.
# Two traps, both of which this assertion fell into before it worked:
#   - `.*?` is lazy only in PCRE. In a basic-grep pattern `\?` just makes the
#     preceding `.*` optional, so the match ran past this row and counted the next
#     one's links too. Hence perl.
#   - "elsewhere" is also the homepage link list's own label, and it appears first
#     in the document. The anchor must carry the footer's own class, or the match
#     starts in the wrong block entirely.
foot_row=$(tr '\n' ' ' < "$DIST/index.html" \
  | perl -ne 'print $1 if m{tty-foot__mark">elsewhere<(.*?)<span class="tty-spacer">}' || true)
foot_links=$(printf '%s' "$foot_row" | grep -oF '</a>' | wc -l || true)
foot_seps=$(printf '%s' "$foot_row" | grep -oF '·' | wc -l || true)
if [ "$foot_links" -gt 0 ] && [ "$foot_seps" -eq $((foot_links - 1)) ]; then
  pass "the footer separates its links without a dangling one ($foot_links links, $foot_seps separators)"
else
  bad "the footer separates its links without a dangling one ($foot_links links, $foot_seps separators)"
fi
grep_in "posts/index.html" 'aria-current="page"' "the active tab is marked on /posts/"
grep_in "index.html" 'content="#0A0A09"' "the theme colour is the root surface"
grep_not "index.html" "mobile-menu-toggle" "the old hamburger is gone"
grep_not "index.html" "page-header-content" "the old page header is gone"

# The resume is the one nav item whose target is not a page. .eleventy.js passes
# the PDF through, so it never enters collections.all, and nav.njk's `liveUrls`
# gate — which hides a tab whose page the build did not write — would hide it
# forever. `asset: true` opts it out of that gate, so the gate no longer guards
# this URL and these assertions take that job over: the tab exists, it reaches
# every page, it opens safely, its accessible name is honest, and a file really
# sits at the href it points to.
#
# The filename is written nowhere in this script. It is read back out of the
# built nav, so renaming the PDF stays a one-line edit in nav.njk instead of a
# two-file edit that turns CI red in between. Every other needle is
# template-owned markup: a class name, an attribute, a phrase nav.njk itself
# writes.
section "resume in the header menu"
resume_link=$(grep -oE '<a class="tty-tabs__tab" href="[^"]*\.pdf"[^>]*>[^<]*</a>' \
  "$DIST/index.html" 2>/dev/null | head -1)
resume_href=$(printf '%s' "$resume_link" | sed -ne 's/.*href="\([^"]*\)".*/\1/p')
if [ -n "$resume_href" ]; then
  pass "the header menu carries a tab that links a PDF ($resume_href)"
else
  bad "the header menu carries a tab that links a PDF (no .pdf tab in the strip)"
fi

# A nav partial that renders on one page and not another is the failure this
# guards: grep -L lists the pages that DO NOT carry the tab, and every HTML page
# the build writes carries the nav. An empty $resume_href would turn the needle
# into `href=""`, which matches nothing and would make -L report no offenders at
# all, so the empty case fails on its own instead.
#
# The needle carries the tab's class, not the URL alone: footer.njk links the
# same PDF on every page, so a bare href needle passes with the nav tab deleted.
# A mutation test caught exactly that.
if [ -z "$resume_href" ]; then
  bad "the resume tab reaches every page with a nav (there is no tab to look for)"
else
  pages_without_resume=$(grep -rLF --include='*.html' \
    -e "class=\"tty-tabs__tab\" href=\"$resume_href\"" "$DIST" | tr '\n' ' ')
  if [ -n "$pages_without_resume" ]; then
    bad "the resume tab reaches every page with a nav ($pages_without_resume)"
  else
    pass "the resume tab reaches every page with a nav"
  fi
fi

# Scoped to the resume tab's own opening tag. A bare grep of index.html for
# `target="_blank"` would be satisfied by any other new-tab link on the page —
# which is exactly how a page-wide needle goes quietly green after the markup it
# was written for is gone.
if printf '%s\n' "$resume_link" | grep -qF 'target="_blank"'; then
  pass "the resume tab opens in a new tab"
else
  bad "the resume tab opens in a new tab"
fi
if printf '%s\n' "$resume_link" | grep -qF 'rel="noreferrer noopener"'; then
  pass "the new tab is opened safely (noreferrer and noopener)"
else
  bad "the new tab is opened safely (noreferrer and noopener)"
fi

# A link that opens a PDF in a new tab has to say so to a reader who cannot see
# the strip. nav.njk does that with aria-label, which REPLACES the accessible
# name, so two things must hold: the name still contains the visible label (WCAG
# 2.5.3, Label in Name — voice control users say what they read), and it adds
# the two facts the visible text cannot carry.
resume_name=$(printf '%s' "$resume_link" | sed -ne 's/.*aria-label="\([^"]*\)".*/\1/p')
resume_text=$(printf '%s' "$resume_link" | sed -e 's|.*">||' -e 's|</a>||')
# Both halves must be non-empty before the containment test: an empty needle is
# contained in every string, so a vanished tab would otherwise read as a pass
# here (the assertions above are the ones that fail loudly in that case).
if [ -n "$resume_name" ] && [ -n "$resume_text" ] \
  && [ "${resume_name#*"$resume_text"}" != "$resume_name" ]; then
  pass "the resume tab's accessible name keeps its visible label"
else
  bad "the resume tab's accessible name keeps its visible label (name='$resume_name' label='$resume_text')"
fi
case "$resume_name" in
  *PDF*"new tab"*) pass "the accessible name says it is a PDF that opens in a new tab" ;;
  *) bad "the accessible name says it is a PDF that opens in a new tab (name='$resume_name')" ;;
esac

# The gate's own job, done here instead: a tab pointing at a file the build did
# not write is a 404 in the header of every page.
if [ -n "$resume_href" ] && [ -f "$DIST/${resume_href#/}" ]; then
  pass "the resume tab points at a file the build wrote (${resume_href})"
else
  bad "the resume tab points at a file the build wrote (href=${resume_href:-none})"
fi

# The owner asked for the "(14)" post count to go. The count is removed, so the
# class it hung on must be removed too — markup, CSS and all. dist/styles is a
# verbatim passthrough of src/styles, so this sweep covers both trees.
count_class_hits=$(grep -rlF --include='*.html' --include='*.css' -e 'tty-tabs__count' "$DIST" | tr '\n' ' ')
if [ -n "$count_class_hits" ]; then
  bad "no tty-tabs__count survives anywhere in the output ($count_class_hits)"
else
  pass "no tty-tabs__count survives anywhere in the output"
fi
# The one source-side assertion in this file, and it is deliberate: the sweep
# above reads a dist/ that may predate an edit, so a rule re-added to
# src/styles/ for a class no markup uses would sit there unnoticed until the
# next build. The repository root is resolved from this script's own location,
# so the check does not depend on the caller's working directory.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
src_count_hits=$(grep -rlF -e 'tty-tabs__count' "$repo_root/src/styles" | tr '\n' ' ')
if [ -n "$src_count_hits" ]; then
  bad "no tty-tabs__count rule survives in src/styles ($src_count_hits)"
else
  pass "no tty-tabs__count rule survives in src/styles"
fi

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
# I9: --text-faint is 2.67:1 on --surface-raised (the code block background) --
# fails WCAG AA at 11-13px. The Copy button is the only affordance on a code
# block and was near-invisible until hovered. The token is vendored; raise
# the usage to --text-muted (5.15:1 on raised) instead.
grep_in "styles/tty/prism-tty.css" "> button {" "the copy button's own color rule exists"
grep_in "styles/tty/prism-tty.css" "  color: var(--text-muted);" "the copy button clears WCAG AA contrast"

grep_in "posts/how-to-setup-lkd-notes/index.html" 'class="language-' "the post still ships highlighted code"
grep_not "posts/how-to-setup-lkd-notes/index.html" "prism-toolbar.min.css" "the CDN toolbar stylesheet is gone"
grep_in "posts/how-to-setup-lkd-notes/index.html" "prism-toolbar.min.js" "the toolbar script is still injected"

# Long-form reading size and ink. The vendored type scale tops out at 17px for
# --text-lg, which is a UI size: every post body and the whole biography were
# set in it, and in --text-secondary (#B4B4AC, 9.5:1 on the root surface). Both
# were raised. The floor is asserted, not merely the token's existence, because
# "18px at the narrowest screen" is the requirement — a later edit that quietly
# lowered it would leave every structural assertion below still green.
section "reading size and contrast"
grep_in "styles/tty/layout.css" "--tty-prose-size: clamp(18px," "the reading size starts at 18px on the narrowest screen"
grep_in "styles/tty/layout.css" ", 20px)" "the reading size reaches 20px on a desktop"
grep_in "styles/tty/content.css" "font-size: var(--tty-prose-size)" "the prose wrapper reads the reading size"
# Scope to .tty-prose's own block: --text-primary and --text-secondary both
# back other rules in this file, so a bare grep would pass without the fix.
prose_block=$(awk '/^\.tty-prose \{/{f=1} f{print; if (/^}/) exit}' \
  "$DIST/styles/tty/content.css" 2>/dev/null)
if printf '%s\n' "$prose_block" | grep -qF 'color: var(--text-primary);'; then
  pass "the prose body is set in the brightest ink (16.1:1, was 9.5:1)"
else
  bad "the prose body is set in the brightest ink (16.1:1, was 9.5:1)"
fi
if printf '%s\n' "$prose_block" | grep -qF 'var(--text-lg)'; then
  bad "the prose body no longer reads the 17px UI size"
else
  pass "the prose body no longer reads the 17px UI size"
fi
# `.tty-prose .katex { font-size: 1em; }` carries the same string, so a bare
# grep here would pass with the blockquote back at a fixed 15px. Scope it.
quote_block=$(awk '/^\.tty-prose blockquote \{/{f=1} f{print; if (/^}/) exit}' \
  "$DIST/styles/tty/prose.css" 2>/dev/null)
if printf '%s\n' "$quote_block" | grep -qF 'font-size: 1em;'; then
  pass "a blockquote stays at the size it sits in"
else
  bad "a blockquote stays at the size it sits in"
fi
grep_in "styles/tty/prism-tty.css" "font-size: var(--text-md)" "a code block is no longer the smallest text on the site"
grep_in "styles/tty/content.css" "font-size: var(--text-md)" "a post row's description reads as body copy"
# The `.tty-hero__lead` assertion that stood here is gone with the rule: the lead
# string was "" and the element shipped empty. --text-lg has no other reader in
# layout.css, so keeping the needle would have asserted nothing.

# The hero headline is one i18n field and the browser picks the line breaks. It
# used to be three fields (`heroLine1..3`) welded together with hard `<br>` tags,
# which is the defect these four assertions guard against coming back:
#   - no `<br>` on the listing page at all. The hero was its only source; a post
#     BODY may legitimately carry one, but no body is rendered on this page.
#   - the headline caps its own measure and balances its own lines, read out of
#     the `.tty-h1--hero` block itself so a declaration moved elsewhere cannot
#     satisfy it.
#   - no `heroLine`-shaped key survives in any language's strings.
# No fragment of the headline's own words appears below: that is the owner's
# copy, and pinning it would turn CI red on an ordinary wording change (I3).
section "the hero headline is one responsive field"
grep_not "posts/index.html" "<br" "the hero headline carries no hard line break"
hero_block=$(awk '/^\.tty-h1--hero \{/{f=1} f{print; if (/^}/) exit}' \
  "$DIST/styles/tty/layout.css" 2>/dev/null)
for decl in "max-width:" "text-wrap: balance;"; do
  if printf '%s\n' "$hero_block" | grep -qF "$decl"; then
    pass "the hero headline block declares $decl"
  else
    bad "the hero headline block declares $decl"
  fi
done
# The eyebrow above the headline used to repeat the headline word for word, so the
# page printed the same sentence twice. Both elements are wanted; saying the same
# thing twice is not. These two assertions read BOTH strings out of the built page
# and compare them, so neither the sentence nor the page title is written down
# here: the owner can rewrite either at will and only a real duplicate turns CI
# red. That is the I3 rule — assert the relationship, never the copy.
eyebrow_text=$(grep -oE '<p class="tty-eyebrow">[^<]*</p>' "$DIST/posts/index.html" 2>/dev/null \
  | head -1 | sed -E 's|<[^>]*>||g' | tr -s '[:space:]' ' ' | sed -E 's/^ +| +$//g')
hero_text=$(awk '/<h1 class="tty-h1 tty-h1--hero/{f=1} f{print; if (/<\/h1>/) exit}' \
  "$DIST/posts/index.html" 2>/dev/null \
  | sed -E 's|<[^>]*>||g' | tr -s '[:space:]' ' ' | sed -E 's/^ +| +$//g')
if [ -n "$eyebrow_text" ]; then
  pass "the listing hero carries an eyebrow above its headline"
else
  bad "the listing hero carries an eyebrow above its headline"
fi
if [ -n "$eyebrow_text" ] && [ "$eyebrow_text" = "$hero_text" ]; then
  bad "the eyebrow and the headline do not say the same thing"
else
  pass "the eyebrow and the headline do not say the same thing"
fi
# Source-side, and for the same reason as the tty-tabs__count sweep above: the
# i18n JSON never reaches dist/, so the only place a resurrected per-line key can
# be caught is src/_data. `$repo_root` is resolved at line 369.
# The sweep covers all four language files, not just en.json: a per-line split in
# ja.json is the same defect and is far harder to spot by eye.
heroline_hits=$(grep -rlE '"[A-Za-z]+[Ll]ine[0-9]+"[[:space:]]*:' \
  "$repo_root/src/_data" | tr '\n' ' ')
if [ -n "$heroline_hits" ]; then
  bad "no per-line text key survives in src/_data ($heroline_hits)"
else
  pass "no per-line text key survives in src/_data"
fi

# There is one post collection and one post listing. The `archived: true` flag,
# the `postsActive_<lang>` collection and the /posts/archive/ page are all gone:
# a post is on /posts/ from the day it is written, and it never leaves.
# The oldest post is the probe, because it is the one that used to be hidden.
section "every post is on the posts page"
grep_in "posts/index.html" "Tools I use 2024" "the oldest post is on the posts landing page"
# These assertions read the built HTML, not the frontmatter. Nunjucks escapes the
# apostrophe in "Tools I've been using - 2025" to `&#39;`, so grep the part of the
# title that has no apostrophe in it. That stays correct if the escaping changes.
grep_in "posts/index.html" "been using - 2025" "the newest posts are listed too"
have "posts/my-tools-2024/index.html"
grep_in "feed.xml" "Tools I use 2024" "every post is in the feed"
grep_in "llms.txt" "Tools I use 2024" "every post is in llms.txt"
grep_in "search-index-en.json" "Tools I use 2024" "every post is searchable"
grep_in "sitemap.xml" "/posts/my-tools-2024/" "every post is in the sitemap"
# The feature is gone, not merely unused: the page, the script, the collection,
# the banner and the badge must all be absent. A single surviving piece would
# quietly resurrect a second listing.
absent "posts/archive" "the archive page is gone"
absent "scripts/tty-archive.js" "the archive sort script is gone"
archive_class_hits=$(grep -rlF --include='*.html' --include='*.css' -e 'tty-archive' "$DIST" | tr '\n' ' ')
if [ -n "$archive_class_hits" ]; then
  bad "no tty-archive class survives anywhere in the output ($archive_class_hits)"
else
  pass "no tty-archive class survives anywhere in the output"
fi
grep_not "posts/index.html" '/posts/archive/' "nothing links to the removed archive page"
grep_not "posts/my-tools-2024/index.html" 'class="tty-note tty-note--warn"' \
  "the once-archived post no longer shows an archived banner"
grep_not "posts/index.html" 'tty-badge--warn' "no row carries an archived badge"
grep_in "styles/tty/layout.css" ".tty-list__year" "the year block is renamed for the one list that uses it"

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
# I6: `grep -rn 'aria-live|role="status"' src/ dist/` used to return nothing —
# a reader typing a query was told nothing at all, not the count, not that
# anything happened.
grep_in "index.html" 'aria-live="polite"' "the result count is announced to a screen reader"
grep_in "index.html" 'role="status"' "the result count region has a status role"
grep_in "index.html" 'id="tty-search-results" role="listbox"' "the results are a real listbox"
grep_in "index.html" 'role="combobox"' "the query field is a combobox"
grep_in "index.html" 'aria-controls="tty-search-results"' "the combobox points at its listbox"
# The search control carries a magnifier glyph beside the `/` key hint. It is a
# Unicode character (U+2315) in a named fallback stack, never an SVG and never
# an emoji — the design system's icon rule. The glyph is aria-hidden, so the
# button's accessible name still comes from its aria-label alone.
grep_in "index.html" 'class="tty-nav__search-glyph" aria-hidden="true">⌕' "the search control shows the magnifier glyph"
grep_in "posts/index.html" 'class="tty-nav__search-glyph"' "the glyph reaches every page, like the control"
grep_in "index.html" 'aria-label="Search posts"' "the search button keeps its accessible name"
grep_in "styles/tty/layout.css" ".tty-nav__search-glyph" "the glyph has its own rule"
grep_in "styles/tty/layout.css" "--font-marker:" "the glyph fallback stack is declared on :root"
grep_in "styles/tty/prose.css" "var(--font-marker)" "the list markers still read the same stack"
grep_not "index.html" "<svg" "the icon is a glyph, not an SVG"

# The record the archive page used to hold now lives on /posts/ itself: the
# complete list, numbered, grouped by year, with the tag rail beside it. These
# are the assertions that used to point at /posts/archive/.
section "the complete post record on /posts/"
grep_in "posts/index.html" 'id="y-2026"' "the year sections are anchored"
grep_in "posts/index.html" 'href="#y-2026"' "the by-year rail links to a year"
grep_in "posts/index.html" '/posts/tag/linux/' "the tag rail links to a tag page"
grep_in "posts/index.html" '<details class="tty-foldout">' "the compact filter foldout is present"
grep_in "posts/index.html" 'class="tty-rail--sticky tty-when-desktop"' "the desktop rail is present"
grep_in "posts/index.html" 'class="tty-list__years"' "the rows are grouped by year"
grep_in "posts/index.html" 'class="tty-list__count"' "the list states how many posts it holds"
# The hero owns the page's only h1; the list below it is a second-level block.
# Two h1 elements on one page is a heading-structure defect, and this page is
# the one place where a hero and a list head meet.
count_exactly "posts/index.html" '<h1' 1 "the posts page has exactly one h1"
grep_in "posts/index.html" 'class="tty-h2"' "the list head is an h2 under the hero"
# +23: 52px was hard-coded at .tty-nav's height, the sticky rail's `top` and
# the year anchors' `scroll-margin-top` (plus prose.css's own heading
# scroll-margin-top and this file's old pinned string) -- a future nav-height
# change that missed one would land an anchor with its target hidden under
# the pinned bar. One token, used at all three sites in this file.
count_at_least "styles/tty/layout.css" "var(--tty-nav-h)" 3 \
  "the nav-height token backs .tty-nav, the sticky rail and the year anchors"
# L14: this selector used to carry a no-op override -- core.css's unconditional
# `.tty-menu__item { min-height: var(--row-h) }` already applies below 1280px,
# since core.css's own dense-specific rule is gated to min-width: 1280px,
# mutually exclusive with this rule's old max-width: 1279.98px. Guard against
# that dead rule coming back under the block's new name.
grep_not "styles/tty/layout.css" ".tty-list .tty-menu--dense .tty-menu__item" \
  "the no-op compact-row override (L14) has not come back"
# `aria-current="page"` names one page, so at most one tab may carry it. nav.njk
# relies on no tab URL being a prefix of another; a post page and a tag page are
# both under /posts/, which makes them the cases that would break first.
count_exactly "posts/my-tools-2025/index.html" 'aria-current="page"' 1 \
  "exactly one nav tab is current on a post page"
count_exactly "posts/tag/linux/index.html" 'aria-current="page"' 1 \
  "exactly one nav tab is current on a tag page"

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
grep_not "posts/my-tools-2025/index.html" 'class="tty-note tty-note--warn"' "a post shows no banner"
grep_in "styles/tty/layout.css" ".tty-post__progress" "the post screen CSS is present"
# The post column's `68ch` must be counted at the size the prose is set in, or
# the measure is not 68 characters of anything. One token, read in both files.
grep_in "styles/tty/layout.css" "max-width: var(--measure-prose); font-size: var(--tty-prose-size)" \
  "the post column counts its measure in the reading size"

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
# I9: --text-faint is 3.04:1 on --surface-root -- fails WCAG AA at this size.
# A caption is real prose content on 15 figures, not metadata, so it is
# raised to --text-muted (5.85:1 on root) instead of left at --text-faint.
# --text-muted also backs an unrelated, pre-existing rule (the completed-task
# marker), so a plain grep_in for "color: var(--text-muted)" would pass even
# without this fix. Scope the check to the caption's own rule block.
caption_block=$(awk '/\.tty-prose \.tty-caption,/{f=1} f{print; if (/^}/) exit}' \
  "$DIST/styles/tty/prose.css" 2>/dev/null)
if printf '%s\n' "$caption_block" | grep -qF 'color: var(--text-muted);'; then
  pass "the figure caption clears WCAG AA contrast (--text-muted)"
else
  bad "the figure caption clears WCAG AA contrast (--text-muted)"
fi

section "posts landing page"
have "scripts/tty-typewriter.js"
grep_in "posts/index.html" 'tty-h1--hero' "the hero title is present"
# The eyebrow assertion that stood here asserted the presence of a duplicate: its
# string was the headline, word for word. The negative assertion now lives in
# "the hero headline is one responsive field".
grep_in "posts/index.html" 'class="tty-term"' "the terminal demo is present"
# tty-typewriter.js types data-text into the element, so data-text and the
# element's own text are two copies of one string: the text is what a reader
# without JavaScript sees, and data-text is what everyone else watches appear. If
# they drift, the line silently changes as it types. Neither copy is written down
# here, so the command can be reworded freely.
type_attr=$(grep -oE 'data-text="[^"]*"' "$DIST/posts/index.html" 2>/dev/null | head -1 \
  | sed -E 's/^data-text="//; s/"$//')
type_text=$(grep -oE '<span data-tty-type[^>]*>[^<]*</span>' "$DIST/posts/index.html" 2>/dev/null \
  | head -1 | sed -E 's|<[^>]*>||g')
if [ -n "$type_attr" ] && [ "$type_attr" = "$type_text" ]; then
  pass "the typewriter types the same line it already shows"
else
  bad "the typewriter types the same line it already shows (attr='$type_attr' text='$type_text')"
fi
# The "press / anywhere" hint marks the key as a key. .tty-kbd is the same cap the
# nav's keyhint uses, so a key never renders two ways on one site — which means the
# markup assertion and the CSS assertion both have to hold.
grep_in "posts/index.html" '<kbd class="tty-kbd">' "the search hint marks its key as a key"
grep_in "styles/tty/core.css" ".tty-kbd {" "the standalone key cap has a rule to render with"
grep_in "posts/index.html" 'data-tty-type' "the typewriter target is present"
grep_in "posts/index.html" '/scripts/tty-typewriter.js' "the typewriter script is loaded"
grep_in "posts/index.html" 'class="tty-postrow"' "post rows use the design system row"
grep_in "posts/index.html" 'class="tty-panel__title"' "the feeds panel is present"
grep_in "posts/index.html" "3 endpoints" "the feeds panel counts only its endpoints"
grep_not "posts/index.html" '<h2 class="blog">' "the old Pico post headings are gone"
count_at_least "posts/index.html" 'class="tty-term__path"' 3 "the terminal lists three recent slugs"
# I3: was pinned to 13, which failed CI the moment a post was hidden from this
# page. Nothing is hidden from it any more, so the rule is simply: one row per
# post page the build wrote. Derive the count from the build, never pin it.
all_post_pages=$(find "$DIST/posts" -mindepth 2 -maxdepth 2 -name index.html 2>/dev/null)
total_posts=$(printf '%s\n' "$all_post_pages" | grep -c . || true)
count_exactly "posts/index.html" 'class="tty-postrow"' "$total_posts" \
  "every post the build wrote is listed ($total_posts posts)"
# There used to be a second assertion here, pinning the nav tab's "(14)" count to
# this same number. The count is gone from the nav at the owner's request — and
# it was a content-pinned needle of exactly the kind finding I3 is about, so it
# leaves nothing to replace. The class's absence is asserted in the "resume in
# the header menu" section.

section "tag pages"
have "posts/tag/linux/index.html"
grep_in "posts/tag/linux/index.html" 'class="tty-postrow"' "tag pages use the design system row"
grep_in "posts/tag/linux/index.html" 'class="tty-list__head"' "tag pages reuse the list head"
grep_in "posts/tag/linux/index.html" 'href="/posts/"' "a tag page links back to the full list"
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
# Scoped to the paper row's own tag. These two used to grep the whole page, and
# the header's resume tab now carries both attributes on every page — so the
# page-wide form would stay green with the paper row's attributes deleted.
paper_link=$(grep -oE '<a class="tty-paper" href="[^"]*"[^>]*>' \
  "$DIST/preprints/index.html" 2>/dev/null | head -1)
if printf '%s\n' "$paper_link" | grep -qF 'target="_blank"'; then
  pass "the row opens in a new tab"
else
  bad "the row opens in a new tab"
fi
if printf '%s\n' "$paper_link" | grep -qF 'rel="noreferrer noopener"'; then
  pass "the new tab is opened safely"
else
  bad "the new tab is opened safely"
fi
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
# A paper states where it was published. `venue` is required; `host` (the
# conference a workshop runs inside) and `kind` (short paper, poster) are
# optional, and both must render when present — they are the whole point of the
# two new fields, so a template that silently drops one must fail here.
# These needles are template-owned markup, never the owner's data: the class
# names and the `@ ` separator. Renaming a venue or a paper kind in
# src/_data/preprints.js must never turn CI red — that was finding I3.
grep_in "preprints/index.html" 'class="tty-paper__venue"' "the row states its venue"
grep_in "preprints/index.html" 'class="tty-paper__host">@ ' "the optional host renders after the venue"
grep_in "preprints/index.html" 'class="tty-badge tty-badge--outline"' "the optional paper kind renders as a tag"
grep_in "styles/tty/layout.css" ".tty-paper__venue" "the venue line has its own rule"
grep_in "styles/tty/layout.css" ".tty-paper__host" "the host steps down from the venue"

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
# This replaced `grep_in ... '__key">cv<'`, which pinned the label of one row — and
# the owner then renamed that label to "academic cv" for consistency with the
# contact page, so the assertion failed on a change it should never have noticed.
# That is finding I3 in miniature. Six rows today: git, work, orcid, academic cv,
# resume, feed — the mastodon row is gone with the account. `at_least`, so adding a
# channel is an ordinary authoring action, and only losing one turns CI red.
count_at_least "index.html" 'class="tty-linklist__row"' 6 "the elsewhere list keeps every row"
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

for f in index.html 404.html posts/index.html preprints/index.html contact/index.html; do
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
if [ -f "$DIST/scripts/tty-archive.js" ]; then bad "scripts/tty-archive.js is deleted"; else pass "scripts/tty-archive.js is deleted"; fi
have "scripts/tty-search.js"
have "scripts/tty-progress.js"
have "scripts/tty-typewriter.js"
# Three scripts, not four. Each one is browser code this suite cannot execute,
# so the count is the guard: a fourth file here is an untested surface nobody
# declared.
script_count=$(find "$DIST/scripts" -name '*.js' | grep -c . || true)
if [ "$script_count" -eq 3 ]; then
  pass "the output ships exactly three scripts ($script_count)"
else
  bad "the output ships exactly three scripts (found $script_count)"
fi

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
