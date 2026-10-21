# frozen_string_literal: true

module GuestCta
  module Admin
    class BaselineController < ::Admin::AdminController
      requires_plugin GuestCta::PLUGIN_NAME
      include GuestCta::VariantParams

      def update
        baseline = GuestCta::Variant.baseline(params[:placement].presence || "popup")
        if baseline.update(variant_params(baseline.placement))
          render json: baseline.to_h(with_stats: true)
        else
          render_json_error(baseline)
        end
      end
    end
  end
end
