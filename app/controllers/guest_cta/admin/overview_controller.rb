# frozen_string_literal: true

module GuestCta
  module Admin
    # Compact status of both placements for the overview panel shown on the
    # admin dashboard and at the top of the plugin's own pages.
    class OverviewController < ::Admin::AdminController
      requires_plugin GuestCta::PLUGIN_NAME

      def show
        render json: GuestCta::Dashboard.overview
      end
    end
  end
end
