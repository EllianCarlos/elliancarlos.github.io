const tagSlug = require("../../lib/tagSlug");

module.exports = {
  // Eleventy puts only ONE page of a paginated template into collections. The
  // sitemap needs all of them — every tag page is a real page with its own URL
  // (see the `sitemapPages` collection in .eleventy.js). Eleventy's deep data
  // merge keeps the `data`, `size` and `alias` keys set in src/tag/index.njk.
  pagination: {
    addAllPagesToCollections: true,
  },
  eleventyComputed: {
    permalink(data) {
      const tagPage = data.pagination?.items?.[0];
      if (!tagPage) return false;
      const { lang, tag } = tagPage;
      return lang === "en"
        ? `/posts/tag/${tagSlug(tag)}/index.html`
        : `/${lang}/posts/tag/${tagSlug(tag)}/index.html`;
    },
    locale(data) {
      const tagPage = data.pagination?.items?.[0];
      return tagPage?.lang ?? "en";
    },
    tagPage(data) {
      return data.pagination?.items?.[0] ?? null;
    },
  },
};
