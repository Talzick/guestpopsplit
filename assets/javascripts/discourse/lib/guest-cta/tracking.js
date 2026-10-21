import getURL from "discourse/lib/get-url";

// Shared by every placement: variant assignment, impression observation and
// event pings.

export function readStorage(key) {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function writeStorage(key, value) {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // localStorage unavailable (rare); ignore.
  }
}

// Picks the variant this visitor sees for one placement. During a test the
// choice is random on first view and then pinned under `storageKey`, so
// every visitor keeps seeing the same version.
export function pickVariant(config, storageKey) {
  const test = config?.test;
  if (!test || !test.variants?.length) {
    return config?.baseline;
  }

  let assignment = null;
  try {
    assignment = JSON.parse(readStorage(storageKey) || "null");
  } catch {
    assignment = null;
  }

  if (assignment && assignment.test_id === test.id) {
    const pinned = test.variants.find((v) => v.id === assignment.variant_id);
    if (pinned) {
      return pinned;
    }
  }

  const chosen = test.variants[Math.floor(Math.random() * test.variants.length)];
  writeStorage(
    storageKey,
    JSON.stringify({ test_id: test.id, variant_id: chosen.id })
  );
  return chosen;
}

// Calls `onVisible` once the element is at least half on screen. Returns a
// cleanup function. Used by the in-topic placements (banner and reply), whose
// impression only counts when the visitor actually scrolls to them.
export function observeImpression(element, onVisible) {
  if (typeof IntersectionObserver === "undefined") {
    onVisible();
    return () => {};
  }

  const observer = new IntersectionObserver(
    (entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        onVisible();
        observer.disconnect();
      }
    },
    { threshold: 0.5 }
  );
  observer.observe(element);
  return () => observer.disconnect();
}

// Fire-and-forget counter ping. `keepalive` lets a click event survive the
// page navigating away to the funnel.
export function track(variantId, event) {
  const headers = {
    "Content-Type": "application/json",
    "X-Requested-With": "XMLHttpRequest",
  };
  const token = document.querySelector("meta[name='csrf-token']")?.content;
  if (token) {
    headers["X-CSRF-Token"] = token;
  }
  try {
    fetch(getURL("/guest-cta/events"), {
      method: "POST",
      headers,
      body: JSON.stringify({ variant_id: variantId, event }),
      keepalive: true,
      credentials: "same-origin",
    }).catch(() => {});
  } catch {
    // ignore
  }
}
