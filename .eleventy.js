const fs = require("fs");
const path = require("path");
const sitemap = require("@quasibit/eleventy-plugin-sitemap");
const rss = require("@11ty/eleventy-plugin-rss");
const syntaxHighlight = require("@11ty/eleventy-plugin-syntaxhighlight");
const tagSlug = require("./lib/tagSlug");

const leftPadDate = (n) => {
  if (n > 9) return `${n}`;
  return `0${n}`
}

/** Slug for heading IDs: lowercase, spaces to hyphens, remove non-alphanumeric. */
function slugifyHeading(text) {
  return text
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

/** Strip HTML or Markdown and truncate for search index contentExcerpt (max length in chars). */
function contentExcerptForSearch(raw, maxLength = 2500) {
  if (!raw || typeof raw !== "string") return "";
  const text = raw
    .replace(/<[^>]+>/g, " ")
    .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
    .replace(/[#*_`~]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return text.length <= maxLength ? text : text.slice(0, maxLength);
}

module.exports = function (eleventyConfig) {

  // i18n Configuration
  // Feature flag: flip to true to re-enable the multilingual (i18n) site.
  // When false, the site builds English-only and all language UI is hidden.
  const I18N_ENABLED = false;
  const ALL_LANGUAGES = ["en", "pt", "es", "ja"];
  const languages = I18N_ENABLED ? ALL_LANGUAGES : ["en"];
  const defaultLanguage = "en";

  // Add global data for languages
  eleventyConfig.addGlobalData("languages", languages);
  eleventyConfig.addGlobalData("defaultLanguage", defaultLanguage);
  eleventyConfig.addGlobalData("i18nEnabled", I18N_ENABLED);

  // Add watch targets
  eleventyConfig.addWatchTarget("content/**/*.{svg,webp,png,jpg,jpeg,gif}");

  // Add layout alias for posts
  eleventyConfig.addLayoutAlias("post", "layouts/post.njk");
  eleventyConfig.addLayoutAlias("base", "layouts/base.njk");

  // Add heading IDs for TOC anchor links (same slug as slugifyHeading so links match)
  eleventyConfig.amendLibrary("md", (mdLib) => {
    mdLib.use(require("markdown-it-anchor"), {
      slugify: slugifyHeading,
      permalink: false,
    });
    // Server-side LaTeX math rendering ($inline$ and $$display$$) via KaTeX
    mdLib.use(require("@vscode/markdown-it-katex").default);

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
  });

  eleventyConfig.addPassthroughCopy("src/Ellian_Carlos_Resume.pdf");
  eleventyConfig.addPassthroughCopy("src/robots.txt");
  // NOTE: llms.txt is generated from src/llms.njk, not copied.
  //
  // Copy the `styles` directory to the output
  eleventyConfig.addPassthroughCopy("src/styles");
  eleventyConfig.addPassthroughCopy("src/scripts");
  eleventyConfig.addPassthroughCopy("src/**/*.png");

  // Copy the `public` directory to the output
  eleventyConfig.addPassthroughCopy("public");
  // Explicit passthrough for _headers (underscore-prefixed files are ignored by default)
  eleventyConfig.addPassthroughCopy({"public/_headers": "_headers"});
  
  // Copy favicon files to root
  eleventyConfig.addPassthroughCopy({"public/favicon-16x16.png": "favicon-16x16.png"});
  eleventyConfig.addPassthroughCopy({"public/favicon-32x32.png": "favicon-32x32.png"});
  eleventyConfig.addPassthroughCopy({"public/apple-touch-icon.png": "apple-touch-icon.png"});
  // Android and some feed readers reach for the largest icon on offer. Every one of
  // these needs its own line: addPassthroughCopy("public") above lands the whole
  // directory at dist/public/, not at the site root, so a file added to public/ is
  // NOT served from / until it is named here.
  eleventyConfig.addPassthroughCopy({"public/icon-512.png": "icon-512.png"});
  eleventyConfig.addPassthroughCopy({"public/og-image.png": "og-image.png"});

  // Papers live in preprints/ at the repository root, outside src/, because they
  // are release artefacts rather than site sources. Copy them verbatim; the page
  // that lists them is generated from src/_data/preprints.js.
  eleventyConfig.addPassthroughCopy("preprints");

  // Social thumbnails, one per post, generated by `bun run images`
  // (scripts/make-images.mjs) and committed. They sit at the repository root for
  // the same reason preprints/ does — they are generated artefacts, not sources.
  //
  // NOT under public/: `addPassthroughCopy("public")` copies that whole directory
  // to dist/public/, which post bodies depend on (they reference
  // /public/<image>.png), and the root-level favicons are separate explicit
  // mappings of the same files. Putting 1.2 MB of thumbnails in there would ship
  // every one of them twice. Here they are copied once, and the og:image URLs read
  // /og/<slug>.png rather than /public/og/<slug>.png.
  eleventyConfig.addPassthroughCopy("og");

  // Plugins
  // Canonical tag slug, shared with lib/tagSlug.js used by the permalink builder.
  eleventyConfig.addFilter("tagSlug", tagSlug);

  eleventyConfig.addPlugin(syntaxHighlight);
  eleventyConfig.addPlugin(rss);

  eleventyConfig.addPlugin(sitemap, {
    sitemap: {
      hostname: "https://elliancarlos.com.br",
    },
  });

  // Pretty-print sitemap XML so URL and lastmod are clearly separate when viewed in browser
  eleventyConfig.addTransform("prettyPrintSitemap", function (content, outputPath) {
    if (outputPath && outputPath.endsWith("sitemap.xml")) {
      return content.replace(/></g, ">\n<");
    }
    return content;
  });

  // Pinned to an exact version, not the mutable "@1" tag — see the final
  // whole-branch review (I7): every other third-party reference on this site
  // is pinned the same way (katex, flexsearch, silkscreen, JetBrains Mono).
  const PRISM_PLUGIN_BLOCK = `
<script>window.Prism = window.Prism || {}; Prism.manual = true;</script>
<script src="https://cdn.jsdelivr.net/npm/prismjs@1.30.0/components/prism-core.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/prismjs@1.30.0/plugins/toolbar/prism-toolbar.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/prismjs@1.30.0/plugins/show-language/prism-show-language.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/prismjs@1.30.0/plugins/copy-to-clipboard/prism-copy-to-clipboard.min.js"></script>
<script>
  document.querySelectorAll('pre[class*="language-"] > code').forEach(function(code) {
    var lang = (code.className.match(/language-(\S+)/) || [])[1] || '';
    Prism.hooks.run('complete', { element: code, language: lang, grammar: Prism.languages[lang], code: code.textContent });
  });
</script>
`;

  eleventyConfig.addTransform("injectPrismPlugins", function (content, outputPath) {
    if (outputPath && outputPath.endsWith(".html") && content.includes('<code class="language-')) {
      return content.replace("</body>", PRISM_PLUGIN_BLOCK + "</body>");
    }
    return content;
  });

  // Language-specific post collections
  languages.forEach(lang => {
    eleventyConfig.addCollection(`posts_${lang}`, (collectionApi) => {
      return collectionApi.getFilteredByGlob(`src/${lang}/posts/**/*.md`)
        .sort((a, b) => b.data.date - a.data.date);
    });
  });

  // Map of language -> list of available HTML page URLs.
  // Consumed by languageRedirect.njk so we only auto-redirect when the
  // translated page actually exists, avoiding the /pt/pt/pt/... loop
  // that used to happen when a user's browser language had no translation.
  eleventyConfig.addCollection("availableUrls", (collectionApi) => {
    const result = {};
    languages.forEach((lang) => { result[lang] = []; });
    collectionApi.getAll().forEach((item) => {
      const lang = item.data && item.data.locale;
      if (!lang || !result[lang]) return;
      if (!item.url) return;
      if (!item.outputPath || !item.outputPath.endsWith(".html")) return;
      result[lang].push(item.url);
    });
    return result;
  });

  // Keep original posts collection for backward compatibility (English posts)
  eleventyConfig.addCollection("posts", (collectionApi) => {
    return collectionApi.getFilteredByGlob("src/en/posts/**/*.md")
      .sort((a, b) => b.data.date - a.data.date);
  });

  // Unique tags per language (from posts' frontmatter)
  languages.forEach(lang => {
    eleventyConfig.addCollection(`tags_${lang}`, (collectionApi) => {
      const posts = collectionApi.getFilteredByGlob(`src/${lang}/posts/**/*.md`);
      const tagSet = new Set();
      posts.forEach((p) => {
        (p.data.tags || []).forEach((t) => tagSet.add(t));
      });
      return [...tagSet].sort();
    });
  });

  // All (lang, tag) pairs for generating tag index pages
  eleventyConfig.addCollection("tagPages", (collectionApi) => {
    const pairs = [];
    languages.forEach((lang) => {
      const tags = collectionApi.getFilteredByGlob(`src/${lang}/posts/**/*.md`)
        .reduce((set, p) => {
          (p.data.tags || []).forEach((t) => set.add(t));
          return set;
        }, new Set());
      [...tags].sort().forEach((tag) => pairs.push({ lang, tag }));
    });
    return pairs;
  });

  // The page list src/sitemap.njk hands to the sitemap plugin. It cannot hand
  // over collections.all, because src/tag/index.njk is a paginated template and
  // @quasibit/eleventy-plugin-sitemap replaces any item carrying
  // `data.pagination` with one entry per `pagination.hrefs` entry (the plugin's
  // own src/paginationItems.js). A tag page's real URL comes from the computed
  // permalink in src/tag/tag.11tydata.js, which `hrefs` never sees, so every
  // href for that template is its file-based URL, `/tag/` — a page this build
  // never writes. The plugin then de-duplicated those into a single `/tag/`:
  // sitemap.xml advertised a 404 and listed none of the real
  // /posts/tag/<slug>/ pages.
  //
  // Copying each item into a plain object leaves `data.pagination` behind, so
  // the plugin reads the URL Eleventy actually wrote. Paired with
  // `addAllPagesToCollections` in src/tag/tag.11tydata.js, this is one entry per
  // page the build writes, derived entirely from the build — a post that gains
  // a new tag reaches the sitemap on the next build, with no URL list and no
  // count written down anywhere.
  eleventyConfig.addCollection("sitemapPages", (collectionApi) =>
    collectionApi.getAll().map((item) => ({
      url: item.url,
      date: item.date,
      // The plugin reads per-page overrides (`changefreq`, `priority`,
      // `lastmod`, `ignore`) out of `data.sitemap`; keep them reachable.
      data: { sitemap: item.data.sitemap },
    }))
  );

  // Search index per language: array of { id, title, url, description, date, contentExcerpt }
  languages.forEach((lang) => {
    eleventyConfig.addCollection(`searchIndex_${lang}`, (collectionApi) => {
      const posts = collectionApi.getFilteredByGlob(`src/${lang}/posts/**/*.md`)
        .sort((a, b) => b.data.date - a.data.date);
      return posts.map((p, i) => {
        let rawContent = "";
        try {
          const inputPath = p.inputPath && path.isAbsolute(p.inputPath)
            ? p.inputPath
            : path.join(process.cwd(), p.inputPath || "");
          rawContent = fs.readFileSync(inputPath, "utf8");
        } catch (_) {
          rawContent = (p.inputContent || p.templateContent) || "";
        }
        return {
          id: String(i),
          title: p.data.title || "",
          url: p.url || "",
          description: p.data.description || "",
          date: p.data.date
            ? `${p.data.date.getFullYear()}-${leftPadDate(p.data.date.getMonth() + 1)}-${leftPadDate(p.data.date.getDate())}`
            : "",
          contentExcerpt: contentExcerptForSearch(rawContent),
        };
      });
    });
  });

  // JSON stringify filter for search index output
  eleventyConfig.addFilter("json", (obj) => JSON.stringify(obj));

  // Filter posts that have a given tag
  eleventyConfig.addFilter("filterByTag", (posts, tag) => {
    if (!Array.isArray(posts) || !tag) return [];
    return posts.filter((p) => (p.data.tags || []).includes(tag));
  });

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

  // Zero-padded three-digit index, for a list that is not a post collection.
  eleventyConfig.addFilter("pad3", (n) => String(n).padStart(3, "0"));

  // The entry after `url`, wrapping to the first. Drives the "next" link on a
  // post page. Returns null when the url is not in the list.
  eleventyConfig.addFilter("nextPost", (posts, url) => {
    if (!Array.isArray(posts) || posts.length === 0) return null;
    const i = posts.findIndex((post) => post.url === url);
    if (i < 0) return null;
    return posts[(i + 1) % posts.length] || null;
  });

  /* "1 post", "13 posts". The design system counts exactly: Site.jsx writes
     `result{results.length === 1 ? "" : "s"}`, and tty-search.js does the same. */
  eleventyConfig.addFilter("plural", (count, one, many) => {
    return `${count} ${count === 1 ? one : many}`;
  });

  // i18n URL filter
  eleventyConfig.addFilter("i18nUrl", function(url, lang) {
    if (!lang || lang === defaultLanguage) return url;
    return `/${lang}${url}`;
  });

  // Switch language filter
  eleventyConfig.addFilter("switchLanguage", function(url, targetLang) {
    const currentLang = this.ctx.locale || defaultLanguage;
    if (currentLang === targetLang) return url;
    
    // Remove current language prefix
    let newUrl = url;
    languages.forEach(lang => {
      if (lang !== defaultLanguage && url.startsWith(`/${lang}/`)) {
        newUrl = url.replace(`/${lang}/`, '/');
      }
    });
    
    // Add new language prefix (if not default)
    if (targetLang !== defaultLanguage) {
      newUrl = `/${targetLang}${newUrl}`;
    }
    
    return newUrl;
  });

  // Permalink computation for language directories
  eleventyConfig.addGlobalData("permalink", function() {
    return (data) => {
      const locale = data.locale || defaultLanguage;
      const filePathStem = data.page.filePathStem;
      
      // Remove language prefix from path
      let path = filePathStem.replace(`/${locale}/`, '/');
      
      // For default language (English), serve at root
      if (locale === defaultLanguage) {
        // Special case for homepage - serve at root
        if (path === '/index') {
          return '/index.html';
        }
        // Special case for index pages (e.g., /posts/index -> /posts/index.html)
        if (path.endsWith('/index')) {
          return `${path}.html`;
        }
        return `${path}/index.html`;
      }
      
      // Special case for homepage in non-English languages
      if (path === '/index') {
        return `/${locale}/index.html`;
      }
      
      // Special case for index pages in non-English languages
      if (path.endsWith('/index')) {
        return `/${locale}${path}.html`;
      }
      
      // For other languages, add language prefix
      return `/${locale}${path}/index.html`;
    };
  });

  eleventyConfig.addFilter("postDate", date => {
    return `${date.getFullYear()}-${leftPadDate(date.getMonth() + 1)}-${leftPadDate(date.getDate())}`
  });

  return {
    dir: {
      input: "src",
      output: "dist",
      includes: "_includes",
      data: "_data",
    },
  };
};
