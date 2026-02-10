module.exports = {
  eleventyComputed: {
    permalink(data) {
      const tagPage = data.pagination?.items?.[0];
      if (!tagPage) return false;
      const { lang, tag } = tagPage;
      return lang === "en"
        ? `/posts/tag/${tag}/index.html`
        : `/${lang}/posts/tag/${tag}/index.html`;
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
