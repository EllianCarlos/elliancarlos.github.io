/**
 * Papers listed at /preprints/. Newest first — the template does not sort.
 *
 * Required fields, all strings:
 *   title    the paper title, as printed on the PDF
 *   authors  the full author list, in the printed order, separated by ", "
 *   venue    where the paper was published: the workshop, conference or journal
 *            that accepted it, with its year — or "preprint" if nothing has
 *            accepted it yet
 *   date     YYYY-MM-DD. The day the paper was PRESENTED at `venue` — not the
 *            day this entry was written, and not the camera-ready date. For a
 *            workshop, that is the workshop's own day, which is often one day
 *            inside a longer `host` conference. Take it from the venue's own
 *            published programme, never from a previous year's schedule.
 *   pdf      site-absolute URL under /preprints/, matching a file in the
 *            repository-root preprints/ directory
 *
 * Optional fields, both strings, both omitted by leaving the key out:
 *   host     the umbrella event a workshop runs inside. The row prints
 *            "<venue> @ <host>", so name the workshop in `venue` and the
 *            conference here.
 *   kind     a short label for the paper's category — "short paper",
 *            "full paper", "poster", "extended abstract". It renders as a tag
 *            beside the date. Keep it two words at most: the tag does not wrap.
 *
 * Adding a paper is two steps: drop the PDF in preprints/ and add an entry here.
 */
module.exports = [
  {
    title:
      "Corporate Truck Factor: Firm-Level Knowledge Concentration in Linux Kernel Subsystems",
    authors:
      "Ellian Carlos Costa, Gabriel Braga Lagrotaria, Ricardo Hideki Hangai Kojo, Arthur Pilone, Paulo Meirelles",
    venue: "VEM 2026",
    host: "CBSOFT 2026",
    kind: "short paper",
    // VEM 2026 runs on 11 September 2026, one day inside CBSOFT 2026
    // (8-11 September 2026, IME-USP, Sao Paulo). Confirmed on the workshop's own
    // programme at https://vemworkshop.github.io/vem2026 and on the CBSOFT
    // schedule. The previous value, 2026-09-21, matched neither.
    date: "2026-09-11",
    pdf: "/preprints/Corporate_Truck_Factor__Firm_Level_Knowledge_Concentration_in_Linux_Kernel_Subsystems.pdf",
  },
];
