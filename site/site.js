(() => {
  const input = document.querySelector("#repository-url");
  const status = document.querySelector("#copy-status");

  if (!(input instanceof HTMLInputElement) || !(status instanceof HTMLElement)) {
    return;
  }

  const selectAddress = () => {
    input.focus();
    input.select();
    input.setSelectionRange(0, input.value.length);
  };

  input.addEventListener("focus", selectAddress);
  input.addEventListener("click", async () => {
    selectAddress();
    try {
      if (!navigator.clipboard || !window.isSecureContext) {
        throw new Error("clipboard unavailable");
      }
      await navigator.clipboard.writeText(input.value);
      status.textContent = "Repository address copied.";
    } catch {
      status.textContent = "Repository address selected. Copy it manually.";
    }
  });
})();
