const fs = require("fs");
const path = require("path");
const sitemap = require("@quasibit/eleventy-plugin-sitemap");

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

const sneakPeak = (postText, imagePostUrl, textBeforeImage, textAfterImage) => {
  let firstText = postText.replace(/<[^>]+>/g, "").slice(0, 255) + "...";

  let imagePost = "";
  let lastText = "";

  if (textBeforeImage) {
    firstText = textBeforeImage;
  }

  if (textAfterImage) {
    lastText = textAfterImage;
  }

  if (imagePostUrl) {
    imagePost = `<img src="${imagePostUrl}" />`;
  } else {
    const imgReg = new RegExp('<\s*?img\s+[^>]*?\s*src\s*=\s*(["\'])((\\?+.)*?)\1[^>]*?>');
    // const imgReg = new RegExp('<\\s*?img\\s+[^>]*?\\s*src\\s*=\\s*(["\'])(([\\x3F]+.)*?)\\1[^>]*?>');
    if (postText.match(imgReg)) imagePost = imgReg.exec(postText)[0];
  }


  return `${firstText}\n${imagePost}\n${lastText}`;
}

module.exports = function (eleventyConfig) {

  // i18n Configuration
  const languages = ["en", "pt", "es", "ja"];
  const defaultLanguage = "en";

  // Add global data for languages
  eleventyConfig.addGlobalData("languages", languages);
  eleventyConfig.addGlobalData("defaultLanguage", defaultLanguage);

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
  });

  eleventyConfig.addPassthroughCopy("src/Ellian_Carlos_Resume.pdf");
  eleventyConfig.addPassthroughCopy("src/robots.txt");
  //
  // Copy the `styles` directory to the output
  eleventyConfig.addPassthroughCopy("src/styles");
  eleventyConfig.addPassthroughCopy("src/scripts");
  eleventyConfig.addPassthroughCopy("src/**/*.png");

  // Copy the `public` directory to the output
  eleventyConfig.addPassthroughCopy("public");
  
  // Copy favicon files to root
  eleventyConfig.addPassthroughCopy({"public/favicon-16x16.png": "favicon-16x16.png"});
  eleventyConfig.addPassthroughCopy({"public/favicon-32x32.png": "favicon-32x32.png"});
  eleventyConfig.addPassthroughCopy({"public/apple-touch-icon.png": "apple-touch-icon.png"});
  eleventyConfig.addPassthroughCopy({"public/og-image.png": "og-image.png"});

  // Plugins
  eleventyConfig.addPlugin(sitemap, {
    sitemap: {
      hostname: "https://www.elliancarlos.com.br",
    },
  });

  // Pretty-print sitemap XML so URL and lastmod are clearly separate when viewed in browser
  eleventyConfig.addTransform("prettyPrintSitemap", function (content, outputPath) {
    if (outputPath && outputPath.endsWith("sitemap.xml")) {
      return content.replace(/></g, ">\n<");
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

  // Search index per language: array of { id, title, url, description, contentExcerpt }
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

  // Check if post translation exists
  eleventyConfig.addFilter("postInLanguage", function(post, targetLang) {
    if (!post || !post.data || !post.data.translationKey) return false;
    const allPosts = this.ctx.collections[`posts_${targetLang}`] || [];
    return allPosts.some(p => p.data.translationKey === post.data.translationKey);
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

  eleventyConfig.addFilter("sneakPeakPost", function (data) {
    return sneakPeak(data.content)
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
