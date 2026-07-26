// Changing Code summary text
document.querySelectorAll("div[data-code-filename]").forEach((div) => {
  // No <summary> when code-fold is off: there is no fold label to rewrite.
  let summary = div.querySelector("summary");
  if (!summary) return;
  summary.textContent = div.getAttribute("data-code-filename");
});
