export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("guest-cta-ab-dashboard", { path: "popup" });
    this.route("guest-cta-ab-banner", { path: "banner" });
    this.route("guest-cta-ab-reply", { path: "reply" });
  },
};
