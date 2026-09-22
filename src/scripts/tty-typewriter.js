/* Typewriter for the terminal demo on /posts/.
   Reads data-text and data-speed off each [data-tty-type] element and types the
   string on a loop, holding the finished line before it restarts.

   Under prefers-reduced-motion the text is written once and the timer never
   starts — the design system collapses every duration in that case, and a loop
   with no duration would flicker. */
(function () {
  var nodes = document.querySelectorAll("[data-tty-type]");
  if (nodes.length === 0) return;

  var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  for (var i = 0; i < nodes.length; i++) {
    run(nodes[i]);
  }

  function run(el) {
    var text = el.getAttribute("data-text") || "";
    if (!text) return;

    if (still) {
      el.textContent = text;
      return;
    }

    var speed = parseInt(el.getAttribute("data-speed"), 10) || 55;
    var HOLD_MS = 2400;
    var n = 0;

    el.textContent = "";

    function step() {
      n += 1;
      el.textContent = text.slice(0, n);
      if (n < text.length) {
        window.setTimeout(step, speed);
        return;
      }
      window.setTimeout(function () {
        n = 0;
        el.textContent = "";
        window.setTimeout(step, speed);
      }, HOLD_MS);
    }

    window.setTimeout(step, speed);
  }
})();
