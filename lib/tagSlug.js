/**
 * Canonical slug for a tag, shared by the permalink builder and every template
 * that links to a tag page. Must stay in sync on both sides or tag links 404.
 *
 * "open source software" -> "open-source-software"
 * "MAC5856"              -> "mac5856"
 */
module.exports = function tagSlug(tag) {
  return String(tag)
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
};
