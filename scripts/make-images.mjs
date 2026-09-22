#!/usr/bin/env bun
//
// Generates the site's icons and social thumbnails in the TTY design system.
// Runs as part of `bun run build` — see the "build" script in package.json.
//
// ── Why satori + resvg, and NOT ImageMagick ────────────────────────────────
//
// An earlier version shelled out to `magick`. That cannot ship, and the reason is
// worth keeping: Netlify's build image installs Ubuntu's `imagemagick`, which is
// ImageMagick **6**, whose CLI is `convert`/`identify`. The `magick` command only
// exists in ImageMagick 7. GitHub's ubuntu runner is the same. So the build would
// have failed on both hosts while working on a developer machine with IM7.
//
// Rewriting for IM6 was not the fix either: IM6 is gone from nixpkgs, so its exact
// text-layout behaviour could not be verified anywhere before a production deploy.
//
// satori and @resvg/resvg-js are pinned in package.json and ship prebuilt binaries
// (linux-x64-gnu covers Netlify and GitHub Actions). satori measures text from the
// font file itself rather than asking the system for a font, so the output is
// identical on every host. No system package, no fontconfig, nothing to detect.
//
// ── Why it reads dist/ ────────────────────────────────────────────────────
//
// Reading time comes from the `readingTime` filter in .eleventy.js, which counts
// words in RENDERED html. Recomputing it from markdown would give a different
// number and drift. Reading the built page means a thumbnail can never disagree
// with the page it represents — the same source check-build.sh reads.
//
// That is why `bun run build` runs eleventy TWICE: the first pass produces the
// pages this reads, and the second pass copies the generated PNGs into dist/ and
// lets posts.11tydata.js resolve each post's own ogImage.
//
// Nothing this writes is committed. og/ and the generated icons are gitignored.

import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import satori from "satori";
import { Resvg } from "@resvg/resvg-js";

const ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const DIST = join(ROOT, "dist");
const PUBLIC = join(ROOT, "public");
const OG_DIR = join(ROOT, "og");
const FONT_DIR = join(ROOT, ".fonts-cache");

// ── Design system tokens ───────────────────────────────────────────────────
// Read from src/styles/tty/tokens/colors.css. Those eight files are vendored
// byte-for-byte and must not be edited, so this is a copy, not a second source of
// truth — if a token changes there, change it here in the same commit.
const C = {
  root: "#0A0A09", // --surface-root  / --black-000
  panel: "#121211", // --black-100
  border: "#33332F", // --border-default / --black-400
  yellow: "#FFD400", // --yellow
  red: "#FF5C57", // --red
  green: "#5AF78E", // --green
  primary: "#E8E8E3", // --text-primary  / --white-900
  muted: "#8C8C84", // --text-muted    / --grey-700
};

// URLs are pinned to a COMMIT, not a branch. On `main` a file move or rename would
// break the build silently on the next deploy; a commit sha cannot move. The cache
// directory is gitignored, and CI caches it so a deploy does not depend on the
// fetch succeeding every time.
const FONTS = [
  {
    family: "Silkscreen",
    weight: 400,
    style: "normal",
    file: "Silkscreen-Regular.ttf",
    url: "https://raw.githubusercontent.com/google/fonts/7e8d490955e9d2629cd3095e8dadd6fafe3c16b8/ofl/silkscreen/Silkscreen-Regular.ttf",
  },
  {
    family: "JetBrains Mono",
    weight: 400,
    style: "normal",
    file: "JetBrainsMono-Regular.ttf",
    url: "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/02bb50b082dad9ef8a0f33ac393839202b760223/fonts/ttf/JetBrainsMono-Regular.ttf",
  },
  {
    family: "JetBrains Mono",
    weight: 700,
    style: "normal",
    file: "JetBrainsMono-Bold.ttf",
    url: "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/02bb50b082dad9ef8a0f33ac393839202b760223/fonts/ttf/JetBrainsMono-Bold.ttf",
  },
  {
    family: "JetBrains Mono",
    weight: 700,
    style: "italic",
    file: "JetBrainsMono-BoldItalic.ttf",
    url: "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/02bb50b082dad9ef8a0f33ac393839202b760223/fonts/ttf/JetBrainsMono-BoldItalic.ttf",
  },
];

async function loadFonts() {
  mkdirSync(FONT_DIR, { recursive: true });
  const out = [];
  for (const f of FONTS) {
    const path = join(FONT_DIR, f.file);
    if (!existsSync(path)) {
      process.stdout.write(`  fetching ${f.file}\n`);
      const res = await fetch(f.url);
      if (!res.ok) throw new Error(`${f.file}: HTTP ${res.status} from ${f.url}`);
      writeFileSync(path, Buffer.from(await res.arrayBuffer()));
    }
    const data = readFileSync(path);
    // A truncated download, or an html error page saved under a .ttf name, would
    // render as fallback or blank glyphs instead of failing — silently wrong
    // images, the worst outcome. Check the magic bytes before trusting the file.
    const sfnt = [0x00, 0x01, 0x00, 0x00];
    const otto = [0x4f, 0x54, 0x54, 0x4f];
    const ok = [sfnt, otto].some((sig) => sig.every((b, i) => data[i] === b));
    if (!ok) throw new Error(`${f.file} is not TrueType/OpenType — delete .fonts-cache/ and rerun`);
    out.push({ name: f.family, data, weight: f.weight, style: f.style });
  }
  return out;
}

// satori returns SVG; resvg rasterises it. `fitTo` renders the VECTOR at the target
// size rather than downscaling a bitmap, so a 16px icon stays crisp.
function png(svg, width) {
  return new Resvg(svg, {
    fitTo: { mode: "width", value: width },
    background: C.root,
  })
    .render()
    .asPng();
}

// Plain element objects, not JSX: this file is .mjs and needs no build step of its
// own. satori accepts the same shape React would produce.
const el = (type, style, children) => ({ type, props: { style, children } });

// ── Icons ─────────────────────────────────────────────────────────────────
// A shell prompt and one lowercase `e`: `> e`. The prompt is upright Bold, the `e`
// is Bold ITALIC, the way Euler's number is set.
//
// Silkscreen is not used even though it is the display font everywhere else: it is
// caps-only, so a lowercase `e` renders as a capital E.
//
// Two glyphs is the ceiling for a 16px square. `>_e` was tried and abandoned: three
// glyphs leave about 5px each, and the underscore merges with the `e`'s baseline so
// the whole thing reads as a face rather than a prompt. Stacking `>_` above the `e`
// turns the prompt into a speck. Do not add a third glyph without looking at 16px.
const ICON = 512;
function iconElement() {
  return el(
    "div",
    {
      width: ICON,
      height: ICON,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      backgroundColor: C.root,
      // The gap is what keeps the two glyphs apart at 16px, where the whole square
      // is 16 pixels wide. At half this value they touched.
      gap: 40,
      fontFamily: "JetBrains Mono",
      color: C.yellow,
    },
    [
      // The prompt sits smaller than the letter, as it does on a real terminal line.
      el("div", { display: "flex", fontSize: 200, fontWeight: 700 }, ">"),
      el("div", { display: "flex", fontSize: 300, fontWeight: 700, fontStyle: "italic" }, "e"),
    ],
  );
}

// ── Thumbnails ────────────────────────────────────────────────────────────
// 1200x630 is the Open Graph box every scraper crops to. The image this replaced
// was 2848x1504 and 5.1 MB — over the ceiling several scrapers enforce, so it may
// not have rendered at all on some platforms.
const W = 1200;
const H = 630;
const PAD = 24;

// JetBrains Mono is monospace, so its advance width is exactly 0.6em. That makes the
// wrap deterministic arithmetic rather than a render-and-measure loop: pick the
// largest size whose wrapped line count fits the box. A short title is set large, a
// long one steps down, and neither overflows.
const ADVANCE = 0.6;
const TITLE_SIZES = [56, 50, 44, 38, 32];
const TITLE_LINE_HEIGHT = 1.25;
const TITLE_BOX_H = 250;

function wrapLines(text, fontSize, boxWidth) {
  const perLine = Math.floor(boxWidth / (fontSize * ADVANCE));
  const lines = [];
  let line = "";
  for (const word of text.split(/\s+/)) {
    const candidate = line ? `${line} ${word}` : word;
    if (candidate.length <= perLine || !line) {
      line = candidate;
    } else {
      lines.push(line);
      line = word;
    }
  }
  if (line) lines.push(line);
  return lines;
}

function fitTitle(text, boxWidth) {
  for (const size of TITLE_SIZES) {
    const lines = wrapLines(text, size, boxWidth);
    if (lines.length * size * TITLE_LINE_HEIGHT <= TITLE_BOX_H) return { size, lines };
  }
  // Nothing fit. Clip rather than overflow the panel: a cropped thumbnail beats a
  // build that dies on one unusually long title.
  const size = TITLE_SIZES.at(-1);
  const max = Math.floor(TITLE_BOX_H / (size * TITLE_LINE_HEIGHT));
  process.stdout.write(`        note: title clipped to ${max} lines at ${size}px\n`);
  return { size, lines: wrapLines(text, size, boxWidth).slice(0, max) };
}

const dot = (color) => el("div", { display: "flex", width: 12, height: 12, backgroundColor: color });

function thumbElement({ windowName, command, title, meta }) {
  const inner = W - 128; // panel width: 64px inset on each side
  const { size, lines } = fitTitle(title, inner - 2 * PAD);

  return el(
    "div",
    {
      width: W,
      height: H,
      display: "flex",
      padding: 64,
      backgroundColor: C.root,
      fontFamily: "JetBrains Mono",
    },
    [
      // The terminal window: the same parts as .tty-term on the site.
      el(
        "div",
        {
          display: "flex",
          flexDirection: "column",
          width: "100%",
          border: `1px solid ${C.border}`,
          backgroundColor: C.panel,
        },
        [
          // Title bar: three dots left, the window name centred.
          el(
            "div",
            {
              display: "flex",
              alignItems: "center",
              height: 52,
              paddingLeft: PAD,
              paddingRight: PAD,
              borderBottom: `1px solid ${C.border}`,
            },
            [
              el("div", { display: "flex", gap: 8 }, [dot(C.red), dot(C.yellow), dot(C.green)]),
              el(
                "div",
                {
                  display: "flex",
                  flexGrow: 1,
                  justifyContent: "center",
                  fontSize: 20,
                  color: C.muted,
                  // The dots occupy the left, so pull the centred name back by their
                  // width — otherwise it centres in the space LEFT OVER, not in the
                  // panel, and sits visibly right of centre.
                  marginRight: 52,
                },
                windowName,
              ),
            ],
          ),
          // Body: prompt, title, then the meta row and the mark pinned to the foot.
          el(
            "div",
            {
              display: "flex",
              flexDirection: "column",
              flexGrow: 1,
              padding: PAD,
              paddingTop: 28,
            },
            [
              // `$` is the one yellow character, as in every terminal block on the site.
              el("div", { display: "flex", fontSize: 22, gap: 9 }, [
                el("div", { display: "flex", color: C.yellow }, "$"),
                el("div", { display: "flex", color: C.muted }, command),
              ]),
              el(
                "div",
                {
                  display: "flex",
                  flexDirection: "column",
                  marginTop: 22,
                  fontSize: size,
                  fontWeight: 700,
                  lineHeight: TITLE_LINE_HEIGHT,
                  color: C.primary,
                },
                lines.map((l) => el("div", { display: "flex" }, l)),
              ),
              // Pushes everything after it to the bottom of the panel.
              el("div", { display: "flex", flexGrow: 1 }, ""),
              el("div", { display: "flex", fontSize: 22, color: C.muted }, meta),
              el("div", { display: "flex", alignItems: "center", gap: 8, marginTop: 20 }, [
                el(
                  "div",
                  { display: "flex", fontFamily: "Silkscreen", fontSize: 22, color: C.primary },
                  "elliancarlos",
                ),
                // The nav's caret. A box, not a glyph — Silkscreen carries no block
                // character, and a box keeps its size tied to the text beside it.
                el("div", { display: "flex", width: 10, height: 22, backgroundColor: C.yellow }, ""),
              ]),
            ],
          ),
        ],
      ),
    ],
  );
}

// ── Reading the built pages ───────────────────────────────────────────────
const decode = (s) =>
  s
    .replace(/&#(\d+);/g, (_, d) => String.fromCharCode(Number(d)))
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCharCode(parseInt(h, 16)))
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");

const stripTags = (s) => decode(s.replace(/<[^>]*>/g, " ")).replace(/\s+/g, " ").trim();

function readPost(slug) {
  const file = join(DIST, "posts", slug, "index.html");
  if (!existsSync(file)) return null;
  const html = readFileSync(file, "utf8");

  const title = html.match(/<meta property="og:title" content="([^"]*)"/);
  if (!title) return null;

  // The meta row renders "← posts · <date> · <reading time>". Drop the field that
  // ends in "posts", so the back link never leaks into the thumbnail.
  const block = html.replace(/\n/g, " ").match(/<div class="tty-post__meta">(.*?)<\/div>/);
  const fields = block
    ? stripTags(block[1]).split("·").map((s) => s.trim()).filter(Boolean)
    : [];
  const dateAndTime = fields.filter((f) => !/posts$/.test(f));
  const tags = [...html.matchAll(/class="tty-tag"[^>]*>([^<]*)</g)].map((m) => decode(m[1]).trim());

  return {
    slug,
    title: decode(title[1]),
    meta: [...dateAndTime, tags.slice(0, 3).join(", ")].filter(Boolean).join("   ·   "),
  };
}

// ── Main ──────────────────────────────────────────────────────────────────
if (!existsSync(DIST)) {
  console.error("dist/ does not exist. This reads the built pages — run eleventy first.");
  process.exit(1);
}

mkdirSync(OG_DIR, { recursive: true });
const fonts = await loadFonts();

const render = async (element, width, height, outPath, rasterWidth = width) => {
  const svg = await satori(element, { width, height, fonts });
  writeFileSync(outPath, png(svg, rasterWidth));
};

console.log("icons");
for (const { px, out } of [
  { px: 16, out: "favicon-16x16.png" },
  { px: 32, out: "favicon-32x32.png" },
  { px: 180, out: "apple-touch-icon.png" },
  { px: 512, out: "icon-512.png" },
]) {
  await render(iconElement(), ICON, ICON, join(PUBLIC, out), px);
  console.log(`  icon  ${out} (${px}x${px})`);
}

console.log("thumbnails");
// The site default: every page that is not a post, and any post whose thumbnail has
// not been generated. The homepage's own terminal runs `whoami`, so this shows the
// same command rather than a post's `cat title`.
await render(
  thumbElement({
    windowName: "~",
    command: "whoami",
    title: "Ellian Carlos",
    meta: "software engineer   ·   empirical software engineering   ·   linux kernel",
  }),
  W,
  H,
  join(PUBLIC, "og-image.png"),
);
console.log("  thumb og-image.png (site default)");

const slugs = readdirSync(join(DIST, "posts"), { withFileTypes: true })
  .filter((d) => d.isDirectory() && d.name !== "tag")
  .map((d) => d.name)
  .sort();

let made = 0;
for (const slug of slugs) {
  const post = readPost(slug);
  if (!post) {
    console.log(`  skip  ${slug} (no og:title — not a post page?)`);
    continue;
  }
  await render(
    thumbElement({
      windowName: `~/posts/${slug}`,
      command: "cat title",
      title: post.title,
      meta: post.meta,
    }),
    W,
    H,
    join(OG_DIR, `${slug}.png`),
  );
  made += 1;
  console.log(`  thumb og/${slug}.png`);
}

console.log(`\ndone: ${made} post thumbnails, 1 default, 4 icons`);
