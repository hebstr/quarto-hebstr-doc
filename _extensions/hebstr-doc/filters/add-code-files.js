document.querySelectorAll("div[data-code-filename]").forEach((div) => {
  let summary = div.querySelector("summary");
  if (!summary) return;
  summary.textContent = div.getAttribute("data-code-filename");
});
