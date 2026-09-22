const fs = require("node:fs");
const path = require("node:path");

const seo = require("../../_data/seo.js");

// Directory data for src/en/posts/. Gives every post its own social thumbnail
// when one has been generated, and the site default when one has not.
//
// The thumbnails are committed assets under public/og/, produced by
// `bun run images` (scripts/make-images.mjs). The build does NOT generate them:
// rendering needs ImageMagick, which neither CI job installs, so a build that
// shelled out to it would be fragile. See the header of that script.
//
// The consequence to keep in mind: a NEW post has no thumbnail until the script
// runs. That must not break anything, so this falls back to seo.defaultImage
// rather than pointing at a file that does not exist. Writing a post stays a
// one-file action. `check-build.sh` asserts that every og:image a page advertises
// resolves to a real file, so the fallback is checked and so is a typo here.
//
// og:image must be an absolute URL — relative paths are ignored by most scrapers,
// which fetch the tag without the page's base.
//
// The thumbnails live in og/ at the repository ROOT, not under public/: that whole
// directory is copied to dist/public/ as well, so anything inside it ships twice.
// See the passthrough comment in .eleventy.js.
const OG_SRC_DIR = path.join(__dirname, "..", "..", "..", "og");

module.exports = {
  eleventyComputed: {
    ogImage(data) {
      const slug = data.page && data.page.fileSlug;
      if (!slug) return seo.defaultImage;
      const file = path.join(OG_SRC_DIR, `${slug}.png`);
      return fs.existsSync(file)
        ? `${seo.baseUrl}/og/${slug}.png`
        : seo.defaultImage;
    },
  },
};
