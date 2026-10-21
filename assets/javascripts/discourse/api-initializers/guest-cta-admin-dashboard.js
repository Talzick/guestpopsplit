import { apiInitializer } from "discourse/lib/api";
import GuestCtaOverview from "../components/guest-cta/overview";

// Shows the plugin's overview panel (on/off switches and current test stats
// for the popup, the banner and the reply) under the admin dashboard header, which is
// also the admin homepage. Only admins can change site settings, so
// moderators, who can also see the dashboard, do not get the panel.
export default apiInitializer("1.0", (api) => {
  if (!api.getCurrentUser()?.admin) {
    return;
  }

  api.renderInOutlet("admin-dashboard-after-header", GuestCtaOverview);
});
