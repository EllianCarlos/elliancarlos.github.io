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
    mastodon: "https://www.mastodon.social/@elliancarlos",
    lattes: "https://lattes.cnpq.br/3423853440338718",
    orcid: "",
    scholar: "",
    wikidata: "",
  },
};
