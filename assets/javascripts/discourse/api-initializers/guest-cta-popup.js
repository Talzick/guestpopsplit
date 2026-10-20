import { apiInitializer } from "discourse/lib/api";
import {
  buttonStyleVars,
  escapeHtml,
  modalInnerHtml,
} from "../lib/guest-cta/popup-markup";
import {
  pickVariant,
  readStorage,
  track,
  writeStorage,
} from "../lib/guest-cta/tracking";

// Same key the original theme component used, so visitors who dismissed the
// old popup recently are not nagged again straight after the switch.
const SHOWN_KEY = "guest_cta_gate_last_shown";
const ASSIGNMENT_KEY = "guest_cta_assignment";

export default apiInitializer("1.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.guest_cta_enabled || !siteSettings.guest_cta_popup_enabled) {
    return;
  }

  // Logged-in users never see the popup.
  if (api.getCurrentUser()) {
    return;
  }

  const site = api.container.lookup("service:site");
  const config = site.guest_cta?.popup;
  if (!config || !config.baseline) {
    return;
  }

  // Frequency cap: if it was shown recently, stay quiet.
  const freqMs = Number(siteSettings.guest_cta_show_frequency_hours) * 60 * 60 * 1000;
  if (freqMs > 0) {
    const last = parseInt(readStorage(SHOWN_KEY) || "0", 10);
    if (Date.now() - last < freqMs) {
      return;
    }
  }

  const markShown = () => writeStorage(SHOWN_KEY, String(Date.now()));

  // Pick the variant up front: the delay is part of what is being tested, so
  // it has to be known before the popup shows. Impressions are still counted
  // only when the popup actually appears, so a long delay that visitors leave
  // before shows up as fewer impressions for that variant.
  const variant = pickVariant(config, ASSIGNMENT_KEY);

  const show = () => {
    // Re-check: they may have logged in during the delay,
    // or the popup may already be on screen.
    if (api.getCurrentUser() || document.querySelector(".gcg-overlay")) {
      return;
    }

    const overlay = document.createElement("div");
    overlay.className = "gcg-overlay";
    Object.entries(buttonStyleVars(variant)).forEach(([k, v]) =>
      overlay.style.setProperty(k, v)
    );

    overlay.innerHTML = `
      <div class="gcg-modal" role="dialog" aria-modal="true" aria-label="${escapeHtml(variant.heading)}">
        ${modalInnerHtml(variant, {
          showClose: siteSettings.guest_cta_show_close_button,
        })}
      </div>
    `;

    const dismiss = () => {
      markShown();
      overlay.remove();
      document.removeEventListener("keydown", onKeydown);
    };

    const onKeydown = (event) => {
      if (event.key === "Escape") {
        dismiss();
      }
    };

    overlay.addEventListener("click", (event) => {
      if (event.target.closest(".gcg-button")) {
        // Let the link navigate, but don't nag them again on return.
        markShown();
        track(variant.id, "click");
        return;
      }
      if (event.target.closest(".gcg-close")) {
        dismiss();
        return;
      }
      if (
        event.target === overlay &&
        siteSettings.guest_cta_close_on_background_click
      ) {
        dismiss();
      }
    });

    document.addEventListener("keydown", onKeydown);
    document.body.appendChild(overlay);
    track(variant.id, "impression");
  };

  // The delay belongs to the variant (0 = straight away) so it can be tested.
  const delayMs = Math.max(0, (Number(variant.show_delay_seconds) || 0) * 1000);
  setTimeout(show, delayMs);
});
