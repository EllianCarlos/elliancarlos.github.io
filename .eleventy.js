const leftPadDate = (n) => {
  if (n > 9) return `${n}`;
  return `0${n}`
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

  // Add watch targets
  eleventyConfig.addWatchTarget("content/**/*.{svg,webp,png,jpg,jpeg,gif}");

  // Add layout alias for posts
  eleventyConfig.addLayoutAlias("post", "layouts/post.njk");
  eleventyConfig.addLayoutAlias("base", "layouts/base.njk");

  eleventyConfig.addPassthroughCopy("src/Ellian_Carlos_Resume.pdf");
  //
  // Copy the `styles` directory to the output
  eleventyConfig.addPassthroughCopy("src/styles");
  eleventyConfig.addPassthroughCopy("src/**/*.png");

  // Copy the `public` directory to the output
  eleventyConfig.addPassthroughCopy("public");

  // Plugins
  // None yet


  eleventyConfig.addCollection("posts", (collectionApi) => {
    return [ ...collectionApi.getFilteredByGlob("src/posts/**.md"),...collectionApi.getFilteredByGlob("src/posts/*/*.md")].sort((a,b) => b.data.date - a.data.date);
  });

  eleventyConfig.addFilter("postDate", date => {
    return `${date.getFullYear()}-${leftPadDate(date.getMonth() + 1)}-${leftPadDate(date.getDay())}`
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
