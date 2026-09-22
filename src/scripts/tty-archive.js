/* Archive sort toggle. Flips one class on #tty-archive; the CSS reverses both
   the year list and the rows inside each year. No rows move in the DOM, so the
   index numbers cannot drift out of step with their posts.

   The choice is not persisted. The order is visible in one glance, so a stored
   preference would only surprise the reader on the next visit. */
(function () {
  var root = document.getElementById("tty-archive");
  if (!root) return;

  var buttons = root.querySelectorAll("[data-tty-sort]");
  if (buttons.length === 0) return;

  function apply(order) {
    if (order === "oldest") root.classList.add("tty-archive--oldest");
    else root.classList.remove("tty-archive--oldest");
    for (var i = 0; i < buttons.length; i++) {
      var on = buttons[i].getAttribute("data-tty-sort") === order;
      buttons[i].setAttribute("aria-selected", on ? "true" : "false");
    }
  }

  for (var i = 0; i < buttons.length; i++) {
    buttons[i].addEventListener("click", function () {
      apply(this.getAttribute("data-tty-sort"));
    });
  }
})();
