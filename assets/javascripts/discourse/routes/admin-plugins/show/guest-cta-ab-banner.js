import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowGuestCtaAbBannerRoute extends DiscourseRoute {
  model() {
    return ajax("/guest-cta/admin/dashboard.json", {
      data: { placement: "banner" },
    });
  }
}
