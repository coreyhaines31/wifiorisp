// Household needs calculator. Same math as the app's HomeProfile.
(() => {
  const $ = (id) => document.getElementById(id);
  const form = $("needs-form");
  if (!form) return;
  const update = () => {
    const people = Number($("n-people").value) || 1;
    const calls = $("n-calls").checked;
    const gaming = $("n-gaming").checked;
    const streams = Number($("n-streams").value) || 0;
    const uploads = $("n-uploads").checked;
    const down = Math.max(25, people * 10 + streams * 25 + (gaming ? 15 : 0) + (calls ? 5 : 0));
    const up = Math.max(5, (calls ? people * 3 : 2) + (uploads ? 20 : 0));
    $("n-down").textContent = `${down} Mbps`;
    $("n-up").textContent = `${up} Mbps`;
    $("n-note").textContent = up > 20
      ? "Upload is your constraint. Cable plans often top out at 20 to 40 Mbps up; fiber is symmetric."
      : "Most cable, fiber, and 5G home plans cover this. Compare upload speeds and lag, not just download.";
  };
  form.addEventListener("input", update);
  update();
})();
