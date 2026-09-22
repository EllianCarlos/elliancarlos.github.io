/* Reading progress for a post page. Writes a whole-number percentage into every
   [data-tty-progress] element. No dependency, no framework.

   The listener is passive and the write is coalesced into one animation frame,
   so a fast scroll does not queue a layout read per event. */
(function () {
  var targets = document.querySelectorAll("[data-tty-progress]");
  if (targets.length === 0) return;

  var queued = false;

  function paint() {
    queued = false;
    var el = document.scrollingElement || document.documentElement;
    var span = el.scrollHeight - el.clientHeight;
    var pct = span <= 0 ? 100 : Math.round((el.scrollTop / span) * 100);
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    for (var i = 0; i < targets.length; i++) {
      targets[i].textContent = pct + "%";
    }
  }

  function onScroll() {
    if (queued) return;
    queued = true;
    window.requestAnimationFrame(paint);
  }

  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll, { passive: true });
  paint();
})();
