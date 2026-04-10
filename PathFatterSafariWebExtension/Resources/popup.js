const statusLabel = document.getElementById("url-status");
const resultLabel = document.getElementById("result");
const openButton = document.getElementById("open-button");
const copyToggle = document.getElementById("copy-toggle");

const webext = globalThis.browser ?? globalThis.chrome;
let currentUrl = "";

function isSharePointUrl(value) {
  try {
    const parsed = new URL(value);
    return parsed.hostname.toLowerCase().includes("sharepoint.com");
  } catch {
    return false;
  }
}

function setStatus(text, ok = true) {
  resultLabel.textContent = text;
  resultLabel.style.color = ok ? "inherit" : "#ff6b6b";
}

function buildDeepLink(url, options = {}) {
  const params = new URLSearchParams();
  params.set("sharepoint", url);
  params.set("open", options.open ? "1" : "0");
  if (options.copy) {
    params.set("copy", "1");
  }
  return `pathfatter://open?${params.toString()}`;
}

function queryActiveTab() {
  if (!webext?.tabs?.query) {
    return Promise.reject(new Error("Tab APIs are unavailable."));
  }

  try {
    const maybePromise = webext.tabs.query({ active: true, currentWindow: true });
    if (maybePromise && typeof maybePromise.then === "function") {
      return maybePromise;
    }
  } catch {
    // Fall through to callback variant.
  }

  return new Promise((resolve, reject) => {
    webext.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const err = webext.runtime?.lastError;
      if (err) {
        reject(new Error(err.message));
        return;
      }
      resolve(tabs ?? []);
    });
  });
}

function openDeepLink(deepLink) {
  const anchor = document.createElement("a");
  anchor.href = deepLink;
  anchor.rel = "noreferrer";
  anchor.style.display = "none";
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // Fallback: some Safari builds ignore synthetic clicks for custom schemes.
  window.location.href = deepLink;
}

async function loadActiveTab() {
  const tabs = await queryActiveTab();
  const tab = tabs[0];
  currentUrl = tab?.url ?? "";

  if (!currentUrl) {
    statusLabel.textContent = "No active tab URL available.";
    openButton.disabled = true;
    return;
  }

  if (!isSharePointUrl(currentUrl)) {
    statusLabel.textContent = "Open a SharePoint page to use PathFatter.";
    openButton.disabled = true;
    return;
  }

  statusLabel.textContent = currentUrl;
  openButton.disabled = false;
}

openButton.addEventListener("click", () => {
  if (!currentUrl) {
    setStatus("No URL found.", false);
    return;
  }

  if (!isSharePointUrl(currentUrl)) {
    setStatus("Current tab is not a SharePoint URL.", false);
    return;
  }

  const deepLink = buildDeepLink(currentUrl, {
    open: true,
    copy: copyToggle.checked
  });

  try {
    openDeepLink(deepLink);
    setStatus("Sent to PathFatter.", true);
    window.setTimeout(() => window.close(), 260);
  } catch {
    setStatus("Unable to open PathFatter.", false);
  }
});

loadActiveTab().catch(() => {
  statusLabel.textContent = "Unable to read the current tab.";
  openButton.disabled = true;
});
