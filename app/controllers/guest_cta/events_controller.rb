# frozen_string_literal: true

module GuestCta
  # Receives impression/click pings from logged-out visitors.
  class EventsController < ::ApplicationController
    requires_plugin GuestCta::PLUGIN_NAME

    skip_before_action :check_xhr, :preload_json, :redirect_to_login_if_required
    # Clicks are sent with `keepalive` as the visitor leaves the page, which can
    # arrive without a usable session; the counters are not sensitive and are
    # rate limited per IP below.
    skip_before_action :verify_authenticity_token, raise: false

    def create
      event = params[:event].to_s
      raise Discourse::InvalidParameters.new(:event) unless DailyStat::EVENTS.include?(event)

      variant_id = params[:variant_id].to_i
      raise Discourse::InvalidParameters.new(:variant_id) if variant_id <= 0

      RateLimiter.new(nil, "guest-cta-events-#{request.remote_ip}", 40, 1.minute).performed!

      raise Discourse::NotFound unless LiveConfig.live_variant_ids.include?(variant_id)

      DailyStat.record!(variant_id, event)
      render json: success_json
    end
  end
end
