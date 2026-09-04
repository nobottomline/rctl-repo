(() => {
  const source = "https://nobottomline.github.io/rctl-repo/";
  const button = document.querySelector("[data-copy-source]");
  const status = document.querySelector("#copy-status");

  if (!(button instanceof HTMLButtonElement) || !(status instanceof HTMLElement)) {
    return;
  }

  const copyFallback = () => {
    const input = document.createElement("textarea");
    input.value = source;
    input.setAttribute("readonly", "");
    input.style.position = "fixed";
    input.style.opacity = "0";
    document.body.append(input);
    input.select();
    const copied = document.execCommand("copy");
    input.remove();
    return copied;
  };

  button.addEventListener("click", async () => {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(source);
      } else if (!copyFallback()) {
        throw new Error("copy unavailable");
      }
      button.textContent = "Copied";
      status.textContent = "Repository URL copied to the clipboard.";
    } catch {
      status.textContent = "Select and copy the repository URL manually.";
    }

    window.setTimeout(() => {
      button.textContent = "Copy source";
      status.textContent = "";
    }, 2400);
  });
})();
