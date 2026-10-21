import { apiInitializer } from "discourse/lib/api";
import AfterFirstPost from "../components/guest-cta/after-first-post";

// Inserts the guest reply and the banner after the first post of every
// topic (guests only; the component checks the post number and the current
// user, and each placement checks its own on/off switch).
export default apiInitializer("1.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.guest_cta_enabled) {
    return;
  }
  if (
    !siteSettings.guest_cta_banner_enabled &&
    !siteSettings.guest_cta_reply_enabled
  ) {
    return;
  }
  if (api.getCurrentUser()) {
    return;
  }

  api.renderAfterWrapperOutlet("post-article", AfterFirstPost);
});
