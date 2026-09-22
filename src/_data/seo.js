module.exports = {
  siteName: "Ellian Carlos",
  baseUrl: "https://elliancarlos.com.br",
  defaultImage: "https://elliancarlos.com.br/og-image.png",
  author: {
    name: "Ellian Carlos",
    url: "https://elliancarlos.com.br",
    // Stable identifier for the Person node. Every other schema that needs an
    // author references this @id instead of re-declaring a Person, so search
    // engines and LLMs resolve one entity rather than N look-alikes.
    id: "https://elliancarlos.com.br/#ellian",
    jobTitle: "Software Development Engineer",
    worksFor: "Amazon",
    affiliation: "University of São Paulo",
    knowsAbout: [
      "Empirical software engineering",
      "Linux kernel",
      "Open source governance",
      "Knowledge concentration",
      "Truck factor",
      "Mining software repositories",
    ],
  },
  // Profiles that resolve to the same real-world person. Anything left empty
  // is dropped from sameAs rather than emitted blank -- fill these in as the
  // accounts are created.
  social: {
    github: "https://www.github.com/elliancarlos",
    linkedin: "https://www.linkedin.com/in/elliancarlos",
    // No mastodon key: the account is not in use. An empty string would read as
    // "not created yet", which is what the note above means, so the key is gone
    // instead. structuredData.njk no longer lists it in sameAs either — leaving a
    // dangling `seo.social.mastodon` there would rely on `| select()` silently
    // dropping an undefined value.
    lattes: "https://lattes.cnpq.br/3423853440338718",
    orcid: "https://orcid.org/0009-0004-9135-8207",
    scholar: "",
    wikidata: "",
  },
};
