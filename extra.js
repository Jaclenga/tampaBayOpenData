// Group two native pkgdown controls; Bootstrap still owns dropdown interaction.
document.addEventListener("DOMContentLoaded", () => {
  const index = document.getElementById("articles-index");
  const toggle = document.getElementById("dropdown-articles-menu");
  if (!index || !toggle) return;

  const indexItem = index.closest("li");
  const dropdown = toggle.closest("li");
  if (indexItem === dropdown) return;

  dropdown.classList.add("articles-split", "d-flex", "flex-wrap", "align-items-center");
  index.classList.add("pe-0");
  toggle.classList.add("dropdown-toggle-split", "px-2");
  dropdown.prepend(index);
  indexItem.remove();
});
