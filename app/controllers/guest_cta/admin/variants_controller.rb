# frozen_string_literal: true

module GuestCta
  module Admin
    class VariantsController < ::Admin::AdminController
      requires_plugin GuestCta::PLUGIN_NAME
      include GuestCta::VariantParams

      def create
        test = GuestCta::Test.find(params[:test_id])
        if test.ended?
          raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.test_ended")
        end

        variant = test.variants.build(variant_params(test.placement))
        variant.placement = test.placement
        if variant.save
          render json: variant.to_h(with_stats: true)
        else
          render_json_error(variant)
        end
      end

      def update
        variant = GuestCta::Variant.find(params[:id])
        if variant.is_baseline
          raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.use_baseline_route")
        end
        if variant.test&.ended?
          raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.test_ended")
        end

        if variant.update(variant_params(variant.placement))
          render json: variant.to_h(with_stats: true)
        else
          render_json_error(variant)
        end
      end

      def destroy
        variant = GuestCta::Variant.find(params[:id])
        if variant.is_baseline || variant.is_control
          raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.cannot_delete_control")
        end
        unless variant.test&.draft?
          raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.not_draft")
        end

        variant.destroy!
        render json: success_json
      end
    end
  end
end
