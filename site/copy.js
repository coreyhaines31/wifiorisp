// Copy buttons for blocks marked data-copy-target="<id>".
(() => {
  document.querySelectorAll("[data-copy-target]").forEach((button) => {
    const label = button.textContent;
    button.addEventListener("click", async () => {
      const text = document.getElementById(button.dataset.copyTarget).textContent;
      try {
        await navigator.clipboard.writeText(text);
        button.textContent = "Copied";
      } catch {
        const range = document.createRange();
        range.selectNodeContents(document.getElementById(button.dataset.copyTarget));
        getSelection().removeAllRanges();
        getSelection().addRange(range);
        button.textContent = "Press ⌘C";
      }
      setTimeout(() => (button.textContent = label), 1800);
    });
  });
})();
