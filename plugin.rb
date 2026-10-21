# frozen_string_literal: true

# name: discourse-guest-cta-ab
# about: Shows a call-to-action popup, a banner and a reply to logged-out visitors and lets admins A/B test variants of each.
# version: 1.0.0
# authors: Talzick
# url: https://github.com/Talzick/guestpopsplit
# required_version: 2.7.0

enabled_site_setting :guest_cta_enabled

register_asset "stylesheets/common/guest-cta.scss"

%w[trophy flask play stop pencil trash-can plus chevron-down chevron-up check xmark rotate].each do |icon|
  register_svg_icon icon
end

module ::GuestCta
  PLUGIN_NAME = "discourse-guest-cta-ab"
end

require_relative "lib/guest_cta/engine"

# With use_new_show_route the location is the plugin name: the sidebar link goes
# to /admin/plugins/<location>, which core resolves to a plugin by name. The
# Popup/Banner pages live under it (see guest-cta-ab-route-map.js).
add_admin_route "guest_cta.admin.title", ::GuestCta::PLUGIN_NAME, use_new_show_route: true

after_initialize do
  # Core only serves /admin/plugins/:plugin_id and /settings itself. In-app
  # navigation to the Popup, Banner and Reply pages needs nothing more, but a refresh
  # or a direct link is a full request, so Rails must know those paths too.
  # Both the plugin name and its install directory are valid ids.
  admin_page_ids = Regexp.union([name, directory_name].uniq.map { |id| Regexp.escape(id) })

  Discourse::Application.routes.append do
    mount ::GuestCta::Engine, at: "/guest-cta"

    scope constraints: StaffConstraint.new do
      ::GuestCta::Variant::PLACEMENTS.each do |page|
        get "admin/plugins/:plugin_id/#{page}",
            to: "admin/plugins#show",
            constraints: {
              plugin_id: admin_page_ids,
            }
      end
    end
  end

  # Logged-out visitors get the live config of every placement preloaded with the rest of the
  # site data, so no extra request is needed before the popup can show.
  add_to_serializer(
    :site,
    :guest_cta,
    include_condition: -> { scope.anonymous? },
  ) { ::GuestCta::LiveConfig.payload }
end
