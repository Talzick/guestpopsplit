// Shared between the live popup (shown to guests) and the admin previews, so
// what the admin sees in the dashboard is exactly what visitors get.

const ESCAPES = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};

export function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (c) => ESCAPES[c]);
}

const HEX = /^#([a-f\d]{6})$/i;

function safeHex(value, fallback) {
  const trimmed = (value || "").trim();
  return HEX.test(trimmed) ? trimmed : fallback;
}

// "#e0113b" -> "224, 17, 59" (used to build the glow color)
export function hexToRgb(hex) {
  const match = HEX.exec((hex || "").trim());
  if (!match) {
    return "224, 17, 59";
  }
  const n = parseInt(match[1], 16);
  return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
}

export function buttonStyleVars(variant) {
  const bg = safeHex(variant.button_color, "#e0113b");
  const fg = safeHex(variant.button_text_color, "#ffffff");
  const rgb = hexToRgb(bg);
  return {
    "--gcg-btn-bg": bg,
    "--gcg-btn-fg": fg,
    "--gcg-glow-soft": `0 0 12px 3px rgba(${rgb}, 0.55)`,
    "--gcg-glow-strong": `0 0 30px 10px rgba(${rgb}, 0.9)`,
  };
}

export function buttonStyle(variant) {
  return Object.entries(buttonStyleVars(variant))
    .map(([k, v]) => `${k}: ${v};`)
    .join(" ");
}

// Inner HTML of the .gcg-modal box. Every value is escaped.
export function modalInnerHtml(variant, { showClose = true, preview = false } = {}) {
  const width = parseInt(variant.image_max_width_px, 10) || 220;
  const imageHtml = variant.image_url
    ? `<img class="gcg-image" src="${escapeHtml(variant.image_url)}" style="max-width:${width}px" alt="" />`
    : "";
  const subheadingHtml = variant.subheading
    ? `<h3 class="gcg-subheading">${escapeHtml(variant.subheading)}</h3>`
    : "";
  const bodyHtml = variant.body_text
    ? `<p class="gcg-body">${escapeHtml(variant.body_text)}</p>`
    : "";
  const closeHtml = showClose
    ? `<button type="button" class="gcg-close" aria-label="Close">&times;</button>`
    : "";
  const targetAttr =
    variant.open_in_new_tab && !preview ? ` target="_blank" rel="noopener"` : "";
  const glowClass = variant.button_glow ? " gcg-glow" : "";
  const href = preview ? "#" : escapeHtml(variant.button_url || "/");
  const extra = preview ? ` tabindex="-1"` : "";

  return `
    ${closeHtml}
    <h2 class="gcg-heading">${escapeHtml(variant.heading)}</h2>
    ${imageHtml}
    ${subheadingHtml}
    ${bodyHtml}
    <a class="gcg-button${glowClass}" href="${href}"${targetAttr}${extra}>${escapeHtml(variant.button_text)}</a>
  `;
}
