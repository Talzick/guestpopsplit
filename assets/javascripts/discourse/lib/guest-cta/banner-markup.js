import { escapeHtml } from "./popup-markup";

// Inner HTML of the banner link. Shared by the live banner and admin previews.
// Every value is escaped. Falls back to the desktop image on mobile when no
// separate mobile image is set.
export function bannerInnerHtml(variant) {
  const desktop = escapeHtml(variant.image_url || "");
  const mobile = escapeHtml(variant.mobile_image_url || variant.image_url || "");
  const alt = escapeHtml(variant.alt_text || "");
  return `
    <img class="gcb-image gcb-image--desktop" src="${desktop}" alt="${alt}" loading="lazy" />
    <img class="gcb-image gcb-image--mobile" src="${mobile}" alt="${alt}" loading="lazy" />
  `;
}
