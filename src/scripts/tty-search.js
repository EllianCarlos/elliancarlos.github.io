/* The `/` search overlay.
   Replaces scripts/search.js, which drove an input embedded in /posts/.

   FlexSearch and the index load on first open, so a reader who never searches
   downloads neither. If the CDN fails, query() falls back to substring matching
   over the same JSON, which is why the fallback is not an error path. */
(function () {
  var FLEX_URL = "https://cdn.jsdelivr.net/npm/flexsearch@0.7.31/dist/flexsearch.bundle.js";
  var DEBOUNCE_MS = 180;

  var overlay = document.getElementById("tty-search");
  if (!overlay) return;

  var panel = overlay.querySelector(".tty-search__panel");
  var input = document.getElementById("tty-search-input");
  var results = document.getElementById("tty-search-results");
  var countEl = document.getElementById("tty-search-count");
  if (!input || !results || !countEl) return;

  var locale = overlay.getAttribute("data-locale") || "en";
  var LABEL = {
    one: overlay.getAttribute("data-s-result") || "result",
    many: overlay.getAttribute("data-s-results") || "results",
    none: overlay.getAttribute("data-s-none") || "no results"
  };

  var docs = null;      // the raw index JSON
  var index = null;     // the FlexSearch Document, or null
  var rows = [];        // the documents currently rendered
  var hi = 0;           // highlighted row
  var loaded = false;   // the fetch has finished, successfully or not
  var loading = false;
  var timer = null;
  var lastFocus = null;

  /* ── loading ──────────────────────────────────────────────────────────── */

  function loadScript(src) {
    return new Promise(function (resolve) {
      var s = document.createElement("script");
      s.src = src;
      s.onload = function () { resolve(true); };
      s.onerror = function () { resolve(false); };
      document.head.appendChild(s);
    });
  }

  function buildIndex(list) {
    var FS = window.FlexSearch;
    var Document = FS && (FS.Document || (FS.default && FS.default.Document));
    if (!Document || !Array.isArray(list) || list.length === 0) return null;
    try {
      var idx = new Document({
        document: { id: "id", index: ["title", "description", "contentExcerpt"], store: true }
      });
      list.forEach(function (doc) { idx.add(doc); });
      return idx;
    } catch (e) {
      return null;
    }
  }

  function load() {
    if (loaded || loading) return Promise.resolve();
    loading = true;
    var wantFlex = window.FlexSearch ? Promise.resolve(true) : loadScript(FLEX_URL);
    return Promise.all([
      wantFlex,
      fetch("/search-index-" + locale + ".json")
        .then(function (r) { return r.json(); })
        .catch(function () { return null; })
    ]).then(function (pair) {
      docs = Array.isArray(pair[1]) ? pair[1] : [];
      index = buildIndex(docs);
      loaded = true;
      loading = false;
    });
  }

  /* ── querying ─────────────────────────────────────────────────────────── */

  function substringQuery(q) {
    var terms = q.toLowerCase().split(/\s+/).filter(Boolean);
    return docs.filter(function (doc) {
      var hay = [doc.title, doc.description, doc.contentExcerpt].join(" ").toLowerCase();
      return terms.every(function (t) { return hay.indexOf(t) !== -1; });
    });
  }

  function flexQuery(q) {
    var out = [];
    var seen = {};
    var raw = index.search({ query: q, enrich: true, limit: 20 });
    if (!Array.isArray(raw)) return out;
    raw.forEach(function (field) {
      (field.result || []).forEach(function (hit) {
        if (!hit || seen[hit.id]) return;
        seen[hit.id] = true;
        out.push(hit.doc !== undefined ? hit.doc : hit);
      });
    });
    return out;
  }

  function query(q) {
    if (!docs) return [];
    if (!q) return docs.slice(0, 20);
    if (!index) return substringQuery(q);
    try {
      return flexQuery(q);
    } catch (e) {
      return substringQuery(q);
    }
  }

  /* ── rendering ────────────────────────────────────────────────────────── */

  function render(list) {
    rows = list;
    hi = 0;
    results.textContent = "";

    if (list.length === 0) {
      var empty = document.createElement("li");
      empty.className = "tty-search__empty";
      empty.setAttribute("role", "presentation");
      empty.textContent = LABEL.none;
      results.appendChild(empty);
      countEl.textContent = LABEL.none;
      input.removeAttribute("aria-activedescendant");
      return;
    }

    list.forEach(function (doc, i) {
      var li = document.createElement("li");
      li.setAttribute("role", "presentation");
      var a = document.createElement("a");
      a.className = "tty-menu__item";
      a.href = doc.url;
      a.id = "tty-search-option-" + i;
      a.setAttribute("role", "option");
      if (i === 0) a.setAttribute("aria-selected", "true");

      var cursor = document.createElement("span");
      cursor.className = "tty-menu__cursor";
      cursor.setAttribute("aria-hidden", "true");
      cursor.textContent = "›";

      var glyph = document.createElement("span");
      glyph.className = "tty-menu__glyph";
      glyph.setAttribute("aria-hidden", "true");
      glyph.textContent = "▸";

      var label = document.createElement("span");
      label.className = "tty-menu__label";
      label.textContent = doc.title;

      a.appendChild(cursor);
      a.appendChild(glyph);
      a.appendChild(label);

      /* Site.jsx puts the date in the row's shortcut slot: the date is what tells
         two posts with similar titles apart. It comes from the build, in the
         index. A document with no date gets no hint and no empty span. */
      if (doc.date) {
        var hint = document.createElement("span");
        hint.className = "tty-menu__hint";
        hint.textContent = doc.date;
        a.appendChild(hint);
      }

      li.appendChild(a);
      results.appendChild(li);
    });

    countEl.textContent = list.length + " " + (list.length === 1 ? LABEL.one : LABEL.many);
    input.setAttribute("aria-activedescendant", "tty-search-option-0");
  }

  function items() {
    return results.querySelectorAll(".tty-menu__item");
  }

  function move(delta) {
    var all = items();
    if (all.length === 0) return;
    if (all[hi]) all[hi].removeAttribute("aria-selected");
    hi = (hi + delta + all.length) % all.length;
    all[hi].setAttribute("aria-selected", "true");
    all[hi].scrollIntoView({ block: "nearest" });
    input.setAttribute("aria-activedescendant", all[hi].id);
  }

  function openHighlighted() {
    var all = items();
    if (all[hi]) window.location.assign(all[hi].getAttribute("href"));
  }

  /* ── open and close ───────────────────────────────────────────────────── */

  function isOpen() { return !overlay.hasAttribute("hidden"); }

  /* The lock goes on <html> and <body>. The vendored breakpoints.css sets
     `html, body { overflow-x: hidden }`, so the root element's own overflow drives
     the viewport and `overflow: hidden` on a body of auto height clips nothing.
     The CSS in layout.css must target both selectors. */
  function lock(on) {
    var root = document.documentElement;
    if (on) {
      root.classList.add("tty-search-open");
      document.body.classList.add("tty-search-open");
    } else {
      root.classList.remove("tty-search-open");
      document.body.classList.remove("tty-search-open");
    }
  }

  function open() {
    if (isOpen()) return;
    lastFocus = document.activeElement;
    overlay.removeAttribute("hidden");
    lock(true);
    setExpanded(true);
    input.focus();
    input.select();
    load().then(function () { render(query(input.value.trim())); });
  }

  function close() {
    if (!isOpen()) return;
    overlay.setAttribute("hidden", "");
    lock(false);
    setExpanded(false);
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }

  function setExpanded(on) {
    var openers = document.querySelectorAll("[data-tty-search-open]");
    for (var i = 0; i < openers.length; i++) {
      openers[i].setAttribute("aria-expanded", on ? "true" : "false");
    }
  }

  /* The overlay is role="dialog" aria-modal="true" with no focus trap, and it
     is included after the footer — so Shift+Tab from the input used to land
     on footer links hidden behind the scrim. Keep focus inside the panel
     while it is open: only the query field and the rendered result links are
     ever focusable in here, so wrap Tab between the first and last of those. */
  function focusableInPanel() {
    return panel.querySelectorAll("input, a[href]");
  }

  function trapTab(e) {
    var focusable = focusableInPanel();
    if (focusable.length === 0) return;
    var first = focusable[0];
    var last = focusable[focusable.length - 1];
    var active = document.activeElement;
    if (e.shiftKey) {
      if (active === first || !panel.contains(active)) {
        e.preventDefault();
        last.focus();
      }
    } else if (active === last || !panel.contains(active)) {
      e.preventDefault();
      first.focus();
    }
  }

  /* ── wiring ───────────────────────────────────────────────────────────── */

  var openers = document.querySelectorAll("[data-tty-search-open]");
  for (var i = 0; i < openers.length; i++) {
    openers[i].addEventListener("click", function (e) { e.preventDefault(); open(); });
    /* nav.njk ships the control with `hidden`, so no page shows a button that
       cannot do anything. This script is what makes the button work, so this
       script is what reveals it. The Task 5 stub does the same thing, and this
       file overwrites that stub. Drop this line and the nav control stays
       invisible on every page: `/` still opens the overlay, and nothing else
       does. The call is safe when the attribute is absent. */
    openers[i].removeAttribute("hidden");
  }

  var closers = overlay.querySelectorAll("[data-tty-search-close]");
  for (var j = 0; j < closers.length; j++) {
    closers[j].addEventListener("click", close);
  }

  input.addEventListener("input", function () {
    if (timer) clearTimeout(timer);
    timer = setTimeout(function () {
      load().then(function () { render(query(input.value.trim())); });
    }, DEBOUNCE_MS);
  });

  input.addEventListener("keydown", function (e) {
    if (e.key === "ArrowDown") { e.preventDefault(); move(1); }
    else if (e.key === "ArrowUp") { e.preventDefault(); move(-1); }
    else if (e.key === "Enter") { e.preventDefault(); openHighlighted(); }
  });

  /* `/` opens the overlay, but only when the reader is not already typing. */
  function typingInAField(el) {
    if (!el) return false;
    var tag = (el.tagName || "").toLowerCase();
    return tag === "input" || tag === "textarea" || tag === "select" || el.isContentEditable;
  }

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && isOpen()) { e.preventDefault(); close(); return; }
    if (e.key === "Tab" && isOpen()) { trapTab(e); return; }
    if (e.key !== "/" || isOpen()) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (typingInAField(document.activeElement)) return;
    e.preventDefault();
    open();
  });
})();
