(function () {
  const DEBOUNCE_MS = 250;
  let debounceTimer = null;
  let searchIndex = null;
  let searchData = null;

  function getConfig() {
    const root = document.getElementById("blog-search-root");
    if (!root) return null;
    return {
      locale: root.dataset.locale || "en",
      noResultsText: root.dataset.noResults || "No results",
    };
  }

  function buildIndex(docs) {
    const FS = typeof FlexSearch !== "undefined" ? FlexSearch : window.FlexSearch;
    const Document = FS?.Document || FS?.default?.Document;
    if (Document && Array.isArray(docs) && docs.length > 0) {
      try {
        const index = new Document({
          document: {
            id: "id",
            index: ["title", "description", "contentExcerpt"],
            store: true,
          },
        });
        docs.forEach(function (doc) {
          index.add(doc);
        });
        return index;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  function fallbackSearch(docs, query) {
    const q = query.toLowerCase().trim();
    if (!q) return docs;
    const terms = q.split(/\s+/).filter(Boolean);
    return docs.filter(function (doc) {
      const text = [
        doc.title || "",
        doc.description || "",
        doc.contentExcerpt || "",
      ]
        .join(" ")
        .toLowerCase();
      return terms.every(function (t) {
        return text.indexOf(t) !== -1;
      });
    });
  }

  function renderResults(results, noResultsText) {
    const container = document.getElementById("blog-search-results");
    const listEl = document.getElementById("blog-search-results-list");
    if (!container || !listEl) return;
    if (!results || results.length === 0) {
      container.hidden = false;
      listEl.innerHTML = "<p class=\"search-no-results\">" + noResultsText + "</p>";
      return;
    }
    const html = results
      .map(
        (doc) =>
          "<article><h2 class=\"blog\"><a class=\"blog\" href=\"" +
          escapeHtml(doc.url) +
          "\">" +
          escapeHtml(doc.title) +
          "</a></h2><p>" +
          escapeHtml((doc.description || doc.contentExcerpt || "").slice(0, 255)) +
          "...</p></article>"
      )
      .join("");
    listEl.innerHTML = html;
    container.hidden = false;
  }

  function escapeHtml(s) {
    const div = document.createElement("div");
    div.textContent = s;
    return div.innerHTML;
  }

  function hideResults() {
    const container = document.getElementById("blog-search-results");
    const listEl = document.getElementById("blog-search-results-list");
    if (container) container.hidden = true;
    if (listEl) listEl.innerHTML = "";
  }

  function runSearch(query, config) {
    const postList = document.getElementById("blog-posts-list");
    if (postList) postList.hidden = !!query.trim();
    if (!query.trim()) {
      hideResults();
      return;
    }
    if (!searchData || !Array.isArray(searchData)) {
      renderResults([], config.noResultsText);
      return;
    }
    var results = [];
    if (searchIndex) {
      try {
        var raw = searchIndex.search({ query: query, enrich: true });
        var ids = new Set();
        // FlexSearch returns [{ field, result: [{ id, doc }, ...] }, ...]
        if (Array.isArray(raw)) {
          raw.forEach(function (fieldResult) {
            var arr = fieldResult.result || [];
            arr.forEach(function (item) {
              if (item && !ids.has(item.id)) {
                ids.add(item.id);
                results.push(item.doc !== undefined ? item.doc : item);
              }
            });
          });
        }
      } catch (e) {
        results = fallbackSearch(searchData, query);
      }
    } else {
      results = fallbackSearch(searchData, query);
    }
    renderResults(results.length ? results : [], config.noResultsText);
  }

  function getQuery() {
    var input = document.getElementById("blog-search-input");
    var mobile = document.getElementById("blog-search-input-mobile");
    var q = input ? input.value.trim() : "";
    if (mobile && mobile.value.trim()) q = mobile.value.trim();
    return q;
  }

  function syncInputs(value) {
    var input = document.getElementById("blog-search-input");
    var mobile = document.getElementById("blog-search-input-mobile");
    if (input) input.value = value;
    if (mobile) mobile.value = value;
  }

  function onInput(evt) {
    const config = getConfig();
    if (!config) return;
    var input = document.getElementById("blog-search-input");
    var mobile = document.getElementById("blog-search-input-mobile");
    var source = evt && evt.target ? evt.target : input;
    var value = source ? source.value : "";
    syncInputs(value);
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function () {
      runSearch(value.trim(), config);
    }, DEBOUNCE_MS);
  }

  function loadIndex(locale, callback) {
    if (searchData) {
      callback();
      return;
    }
    fetch("/search-index-" + locale + ".json")
      .then((r) => r.json())
      .then(function (data) {
        searchData = data;
        searchIndex = buildIndex(data);
        callback();
      })
      .catch(function () {
        callback();
      });
  }

  function init() {
    const config = getConfig();
    if (!config) return;
    const input = document.getElementById("blog-search-input");
    const mobile = document.getElementById("blog-search-input-mobile");
    if (!input && !mobile) return;
    function bind(el) {
      if (el) {
        el.addEventListener("input", onInput);
        el.addEventListener("keyup", onInput);
      }
    }
    bind(input);
    bind(mobile);
    loadIndex(config.locale, function () {
      const q = getQuery();
      if (q) runSearch(q, config);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
