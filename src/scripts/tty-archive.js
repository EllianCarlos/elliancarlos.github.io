/* Archive sort toggle. Reorders the DOM: both the by-year list and the rows
   inside each year. The index numbers (001, 002, ...) are baked into the
   markup as literal text by content.njk's postrow(post, idx[post.url], ...),
   so they stay attached to their post no matter where that post's row sits
   in the DOM — moving nodes cannot make them drift.

   This is a progressive enhancement: the page renders newest-first with no
   script, and the toggle simply does nothing until this loads.

   The choice is not persisted. The order is visible in one glance, so a
   stored preference would only surprise the reader on the next visit. */
(function () {
  var root = document.getElementById("tty-archive");
  if (!root) return;

  var buttons = root.querySelectorAll("[data-tty-sort]");
  if (buttons.length === 0) return;

  var yearsContainer = root.querySelector(".tty-archive__years");
  var rowsContainers = root.querySelectorAll(".tty-archive__rows");
  var currentOrder = "newest";

  function reverseChildren(container) {
    var children = Array.prototype.slice.call(container.children);
    for (var i = children.length - 1; i >= 0; i--) {
      container.appendChild(children[i]);
    }
  }

  function apply(order) {
    if (order !== currentOrder) {
      if (yearsContainer) reverseChildren(yearsContainer);
      for (var i = 0; i < rowsContainers.length; i++) reverseChildren(rowsContainers[i]);
      currentOrder = order;
    }
    for (var i = 0; i < buttons.length; i++) {
      var on = buttons[i].getAttribute("data-tty-sort") === order;
      buttons[i].setAttribute("aria-pressed", on ? "true" : "false");
    }
  }

  for (var i = 0; i < buttons.length; i++) {
    buttons[i].addEventListener("click", function () {
      apply(this.getAttribute("data-tty-sort"));
    });
  }
})();
