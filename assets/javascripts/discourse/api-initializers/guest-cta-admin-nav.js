import { apiInitializer } from "discourse/lib/api";

// Adds "Popup" and "Banner" tabs to the plugin's admin page. The dashboard
// also has its own switcher, so nothing is lost if this API is unavailable.
export default apiInitializer("1.0", (api) => {
  const currentUser = api.getCurrentUser();
  if (!currentUser?.admin || !api.addAdminPluginConfigurationNav) {
    return;
  }

  api.addAdminPluginConfigurationNav("discourse-guest-cta-ab", [
    {
      label: "guest_cta.admin.nav_popup",
      route: "adminPlugins.show.guest-cta-ab-dashboard",
    },
    {
      label: "guest_cta.admin.nav_banner",
      route: "adminPlugins.show.guest-cta-ab-banner",
    },
  ]);
});
