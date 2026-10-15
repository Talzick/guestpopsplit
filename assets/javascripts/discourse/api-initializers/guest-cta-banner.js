import { apiInitializer } from "discourse/lib/api";
import PostBanner from "../components/guest-cta/post-banner";

// Inserts the banner after the first post of every topic (guests only; the
// component itself checks the post number and the current user).
export default apiInitializer("1.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.guest_cta_enabled || !siteSettings.guest_cta_banner_enabled) {
    return;
  }
  if (api.getCurrentUser()) {
    return;
  }

  api.renderAfterWrapperOutlet("post-article", PostBanner);
});
