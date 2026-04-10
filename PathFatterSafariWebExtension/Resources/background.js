function isSharePointUrl(value) {
  try {
    const parsed = new URL(value);
    return parsed.hostname.toLowerCase().includes("sharepoint.com");
  } catch {
    return false;
  }
}

function buildDeepLink(url, options = {}) {
  const params = new URLSearchParams();
  params.set("url", url);
  params.set("open", options.open ? "1" : "0");
  if (options.copy) {
    params.set("copy", "1");
  }
  return `pathfatter://open?${params.toString()}`;
}

async function openDeepLink(deepLink, tabId) {
  if (typeof tabId === "number") {
    try {
      await browser.tabs.update(tabId, { url: deepLink });
      return;
    } catch {
      // Fall through to creating a tab.
    }
  }

  await browser.tabs.create({ url: deepLink });
}

async function openInPathFatter(pageUrl, tabId, options = {}) {
  if (!isSharePointUrl(pageUrl)) {
    return {
      ok: false,
      error: "Current tab is not a SharePoint URL."
    };
  }

  const deepLink = buildDeepLink(pageUrl, options);
  await openDeepLink(deepLink, tabId);

  return {
    ok: true,
    deepLink
  };
}

browser.runtime.onMessage.addListener(async (message, sender) => {
  if (message?.type !== "open-current-tab" && message?.type !== "open-url") {
    return { ok: false, error: "Unsupported message." };
  }

  const pageUrl = message.url;
  const tabId = sender?.tab?.id;
  const options = {
    open: message.open !== false,
    copy: message.copy === true
  };

  return openInPathFatter(pageUrl, tabId, options);
});
