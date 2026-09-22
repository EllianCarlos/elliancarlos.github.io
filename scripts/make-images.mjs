#!/usr/bin/env bun
//
// Generates the site's icons and social thumbnails in the TTY design system.
//
//   bun run build && bun run images && bun run build
//
// Why it is a separate step and not part of `bun run build`:
//
//   Rendering needs ImageMagick with freetype. CI's build job runs on a bare
//   ubuntu-latest image and the devenv job declares only `git`, so a build that
//   shelled out to `magick` would be fragile in both. The PNGs are committed
//   assets instead. `check-build.sh` asserts that every og:image a page points at
//   actually exists, so a broken path always fails; a post with no generated
//   image falls back to the site default, so WRITING a post never fails.
//
// Why it reads dist/ rather than src/:
//
//   Reading time comes from `readingTime` in .eleventy.js, which counts words in
//   RENDERED html. Recomputing it from markdown here would give a different
//   number and would drift. Reading the built page instead means a thumbnail can
//   never disagree with the page it represents. Same source check-build.sh uses.
//
// Why execFileSync and an argv array, not a template-literal shell:
//
//   Post titles here contain `#`, `-` and apostrophes ("LKD - #6 Notes on ..."),
//   every one of which a shell would interpret. An argv array is passed straight
//   to the binary, so no title can ever be re-parsed as syntax. The first version
//   of this script used Bun's `$`, which also treats a newline inside the literal
//   as a command separator — every multi-line invocation silently became several
//   broken commands.
//
// Run order matters: build, generate, build again. The second build copies the
// new PNGs into dist/ and lets each post page pick up its own ogImage.

import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { execFileSync } from "node:child_process";

const ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const DIST = join(ROOT, "dist");
const PUBLIC = join(ROOT, "public");
// Root-level, not public/og: addPassthroughCopy("public") already copies that
// whole tree to dist/public/, so thumbnails placed there would ship twice.
const OG_DIR = join(ROOT, "og");
const FONT_DIR = join(ROOT, ".fonts-cache");
const TMP = join(FONT_DIR, "tmp");

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

// Fonts are fetched, not committed: 850 KB of binary in a repo that holds none
// otherwise. Both families are OFL, so committing them would be legal — this is a
// size and tidiness choice. .fonts-cache/ is gitignored.
const FONTS = {
  mark: {
    file: "Silkscreen-Regular.ttf",
    url: "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Regular.ttf",
  },
  body: {
    file: "JetBrainsMono-Regular.ttf",
    url: "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf/JetBrainsMono-Regular.ttf",
  },
  bold: {
    file: "JetBrainsMono-Bold.ttf",
    url: "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf/JetBrainsMono-Bold.ttf",
  },
  boldItalic: {
    file: "JetBrainsMono-BoldItalic.ttf",
    url: "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf/JetBrainsMono-BoldItalic.ttf",
  },
};

const font = (k) => join(FONT_DIR, FONTS[k].file);

// Every argument reaches the binary verbatim. Numbers are stringified here so a
// caller can pass geometry as numbers without thinking about it.
const magick = (args) =>
  execFileSync("magick", args.map(String), { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });

async function ensureFonts() {
  mkdirSync(FONT_DIR, { recursive: true });
  for (const { file, url } of Object.values(FONTS)) {
    const path = join(FONT_DIR, file);
    if (existsSync(path)) continue;
    process.stdout.write(`  fetching ${file}\n`);
    const res = await fetch(url);
    if (!res.ok) throw new Error(`${file}: HTTP ${res.status} from ${url}`);
    await Bun.write(path, await res.arrayBuffer());
  }
  // A truncated download, or an html error page saved under a .ttf name, renders
  // as blank or fallback glyphs instead of failing — silently wrong images, the
  // worst outcome. Check the magic bytes of every font before drawing with it.
  for (const { file } of Object.values(FONTS)) {
    const head = readFileSync(join(FONT_DIR, file)).subarray(0, 4);
    const sfnt = [0x00, 0x01, 0x00, 0x00];
    const otto = [0x4f, 0x54, 0x54, 0x4f];
    const ok = [sfnt, otto].some((sig) => sig.every((b, i) => head[i] === b));
    if (!ok) {
      throw new Error(`${file} is not a TrueType/OpenType font — delete .fonts-cache/ and rerun`);
    }
  }
}

// ── Icons ─────────────────────────────────────────────────────────────────
// One lowercase `e`, the way Euler's number is set: JetBrains Mono Bold Italic.
//
// Silkscreen cannot do this. It is a caps-only pixel font, so a lowercase `e`
// comes out as a capital E — which is why the display font is not used here even
// though it is the display font everywhere else.
//
// Every size is supersampled from 512px rather than drawn at its final size. A
// 16px `e` drawn directly loses its counter to antialiasing and reads as a blob;
// downscaling from 512 keeps the counter open. `-level` restores the contrast the
// downscale costs, and it is needed most at the smallest size.
function renderIcons() {
  const master = join(TMP, "icon-master.png");
  magick([
    "-size", "512x512", `xc:${C.root}`,
    "-font", font("boldItalic"), "-pointsize", 380,
    "-fill", C.yellow, "-gravity", "center", "-annotate", "+0+28", "e",
    master,
  ]);

  const sizes = [
    { px: 16, out: "favicon-16x16.png", level: "8%,92%" },
    { px: 32, out: "favicon-32x32.png", level: "6%,94%" },
    { px: 180, out: "apple-touch-icon.png", level: "0%,100%" },
    { px: 512, out: "icon-512.png", level: "0%,100%" },
  ];
  for (const { px, out, level } of sizes) {
    magick([
      master, "-filter", "Lanczos", "-resize", `${px}x${px}`,
      "-level", level, "-strip", join(PUBLIC, out),
    ]);
    process.stdout.write(`  icon  ${out} (${px}x${px})\n`);
  }
}

// ── Thumbnails ────────────────────────────────────────────────────────────
// 1200x630 is the Open Graph recommendation and the box every scraper crops to.
// The image this replaced was 2848x1504 and 5.1 MB — over the ceiling several
// scrapers enforce, so it may simply not have rendered on some platforms.
const W = 1200;
const H = 630;
const PX = 64; // panel inset from the canvas
const PY = 64;
const PW = W - 2 * PX;
const PH = H - 2 * PY;
const BAR = 52; // title bar height
const PAD = 24; // panel's inner padding

// Descending sizes, first that fits wins: a short title is set large, a long one
// steps down. Neither overflows, and no title has to be truncated.
const TITLE_W = PW - 2 * PAD;
const TITLE_H = 232;
const TITLE_SIZES = [56, 50, 44, 38, 32];

function titleLayer(text) {
  const out = join(TMP, "title.png");
  for (const ps of TITLE_SIZES) {
    magick([
      "-background", "none", "-fill", C.primary,
      "-font", font("bold"), "-pointsize", ps,
      "-size", `${TITLE_W}x`, "-gravity", "northwest", `caption:${text}`,
      out,
    ]);
    const h = Number(magick([out, "-format", "%h", "info:"]).trim());
    if (h <= TITLE_H) return out;
  }
  // Every size overflowed. Bound the box so the result crops instead of running
  // over the panel: a slightly cropped thumbnail beats a generator that dies on
  // one unusually long title.
  magick([
    "-background", "none", "-fill", C.primary,
    "-font", font("bold"), "-pointsize", TITLE_SIZES.at(-1),
    "-size", `${TITLE_W}x${TITLE_H}`, "-gravity", "northwest", `caption:${text}`,
    out,
  ]);
  process.stdout.write(`        note: title needed cropping at the smallest size\n`);
  return out;
}

function renderThumb({ out, windowName, title, meta, command = "cat title" }) {
  const dotY = PY + 20;
  const dot = (i) => {
    const x = PX + 22 + i * 20;
    return `rectangle ${x},${dotY} ${x + 12},${dotY + 12}`;
  };

  // Window chrome: the panel and its 1px rule, the bar's underline, three dots,
  // and the window name centred — the same parts as .tty-term on the site.
  const base = join(TMP, "base.png");
  magick([
    "-size", `${W}x${H}`, `xc:${C.root}`,
    "-fill", C.panel, "-stroke", C.border, "-strokewidth", 1,
    "-draw", `rectangle ${PX},${PY} ${PX + PW},${PY + PH}`,
    "-stroke", "none",
    "-fill", C.border, "-draw", `rectangle ${PX},${PY + BAR} ${PX + PW},${PY + BAR}`,
    "-fill", C.red, "-draw", dot(0),
    "-fill", C.yellow, "-draw", dot(1),
    "-fill", C.green, "-draw", dot(2),
    "-font", font("body"), "-pointsize", 20, "-fill", C.muted,
    "-gravity", "north", "-annotate", `+0+${PY + 17}`, windowName,
    base,
  ]);

  // The prompt line. `$` is the one yellow character, as in every terminal block
  // on the site; the command itself is muted.
  const promptY = PY + 92;
  const prompt = join(TMP, "prompt.png");
  magick([
    base, "-font", font("body"), "-pointsize", 22, "-gravity", "northwest",
    "-fill", C.yellow, "-annotate", `+${PX + PAD}+${promptY}`, "$",
    // 22px, not 16: JetBrains Mono's advance at 22pt is ~13px, so 16 left the
    // command almost touching the prompt. The command carries no leading space —
    // one would add another full advance and open too wide a gap.
    "-fill", C.muted, "-annotate", `+${PX + PAD + 22}+${promptY}`, command,
    prompt,
  ]);

  const composed = join(TMP, "composed.png");
  magick([
    prompt, titleLayer(title), "-geometry", `+${PX + PAD}+${PY + 136}`, "-composite",
    composed,
  ]);

  // The mark, then the caret measured to sit right after it. Hard-coding the
  // caret's x detaches it from the word as soon as the mark or its size changes —
  // which is exactly what happened in the first draft of this layout.
  const markText = "elliancarlos";
  const markPs = 22;
  const markX = PX + PAD;
  const markY = PY + PH - 46;
  const markProbe = join(TMP, "mark.png");
  magick([
    "-background", "none", "-fill", C.primary,
    "-font", font("mark"), "-pointsize", markPs, `label:${markText}`, markProbe,
  ]);
  const markW = Number(magick([markProbe, "-format", "%w", "info:"]).trim());
  const caretX = markX + markW + 8;

  magick([
    composed,
    "-font", font("body"), "-pointsize", 22, "-fill", C.muted, "-gravity", "northwest",
    "-annotate", `+${PX + PAD}+${PY + PH - 106}`, meta,
    "-font", font("mark"), "-pointsize", markPs, "-fill", C.primary,
    "-annotate", `+${markX}+${markY}`, markText,
    "-fill", C.yellow, "-draw", `rectangle ${caretX},${markY - 2} ${caretX + 10},${markY + 20}`,
    "-strip", "-define", "png:compression-level=9",
    out,
  ]);
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
  console.error("dist/ does not exist. Run `bun run build` first — this reads the built pages.");
  process.exit(1);
}

mkdirSync(TMP, { recursive: true });
mkdirSync(OG_DIR, { recursive: true });

console.log("fonts");
await ensureFonts();

console.log("icons");
renderIcons();

console.log("thumbnails");
// The site default: every page that is not a post, and any post whose thumbnail
// has not been generated yet.
renderThumb({
  out: join(PUBLIC, "og-image.png"),
  windowName: "~",
  // The homepage's own terminal runs `whoami`, so the site thumbnail shows the
  // same command rather than a post's `cat title`.
  command: "whoami",
  title: "Ellian Carlos",
  meta: "software engineer   ·   empirical software engineering   ·   linux kernel",
});
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
  renderThumb({
    out: join(OG_DIR, `${slug}.png`),
    windowName: `~/posts/${slug}`,
    title: post.title,
    meta: post.meta,
  });
  made += 1;
  console.log(`  thumb og/${slug}.png`);
}

rmSync(TMP, { recursive: true, force: true });
console.log(`\ndone: ${made} post thumbnails, 1 default, 4 icons`);
console.log("now run `bun run build` again so the new files reach dist/");
