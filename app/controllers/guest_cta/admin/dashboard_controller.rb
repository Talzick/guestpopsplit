# frozen_string_literal: true

module GuestCta
  module Admin
    class DashboardController < ::Admin::AdminController
      requires_plugin GuestCta::PLUGIN_NAME

      def show
        render json: GuestCta::Dashboard.build(params[:placement].presence || "popup")
      end
    end
  end
end
