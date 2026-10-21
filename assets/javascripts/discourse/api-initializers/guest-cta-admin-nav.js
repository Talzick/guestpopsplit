import { apiInitializer } from "discourse/lib/api";

// Adds "Popup", "Banner" and "Reply" tabs to the plugin's admin page. The dashboard
// also has its own switcher, so nothing is lost if this API is unavailable.
//
// Core looks the nav up by plugin name in the admin sidebar, but by install
// directory name on the plugin's show page (which also picks the default tab
// to redirect to). Register under both so the page works however the plugin
// directory is named.
const PLUGIN_IDS = ["discourse-guest-cta-ab", "guestpopsplit"];

function navLinks() {
  return [
    {
      label: "guest_cta.admin.nav_popup",
      route: "adminPlugins.show.guest-cta-ab-dashboard",
    },
    {
      label: "guest_cta.admin.nav_banner",
      route: "adminPlugins.show.guest-cta-ab-banner",
    },
    {
      label: "guest_cta.admin.nav_reply",
      route: "adminPlugins.show.guest-cta-ab-reply",
    },
  ];
}

export default apiInitializer("1.0", (api) => {
  const currentUser = api.getCurrentUser();
  if (!currentUser?.admin || !api.addAdminPluginConfigurationNav) {
    return;
  }

  PLUGIN_IDS.forEach((pluginId) => {
    api.addAdminPluginConfigurationNav(pluginId, navLinks());
  });
});
