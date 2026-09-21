/* Stub. Task 9 overwrites this file with the overlay controller. layout.njk
   loads this script on every page, so the file must exist from this task, or
   every page requests a 404.
   The one job it has is to keep the nav honest. The search control ships with
   `hidden`, and this stub reveals it only when there is an overlay to open.
   searchOverlay.njk is still empty, so nothing is revealed yet and the reader
   never sees a control that does nothing. */
(function () {
  if (!document.getElementById("tty-search")) return;
  var openers = document.querySelectorAll("[data-tty-search-open]");
  for (var i = 0; i < openers.length; i += 1) {
    openers[i].removeAttribute("hidden");
  }
})();
