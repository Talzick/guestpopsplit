import { ajax } from "discourse/lib/ajax";

// The site setting that switches each placement on or off for visitors.
export const PLACEMENT_SETTINGS = {
  popup: "guest_cta_popup_enabled",
  banner: "guest_cta_banner_enabled",
  reply: "guest_cta_reply_enabled",
};

export function placementEnabled(siteSettings, placement) {
  return !!siteSettings[PLACEMENT_SETTINGS[placement]];
}

// Flips the placement's site setting (admin only) and updates the client's
// copy so every component reading it reacts at once.
export async function setPlacementEnabled(siteSettings, placement, enabled) {
  const key = PLACEMENT_SETTINGS[placement];
  await ajax(`/admin/site_settings/${key}`, {
    type: "PUT",
    data: { [key]: enabled ? "true" : "false" },
  });
  siteSettings[key] = enabled;
}
