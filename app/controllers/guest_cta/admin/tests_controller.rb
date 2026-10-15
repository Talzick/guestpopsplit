# frozen_string_literal: true

module GuestCta
  module Admin
    class TestsController < ::Admin::AdminController
      requires_plugin GuestCta::PLUGIN_NAME

      def create
        test =
          GuestCta::Test.create_with_control!(
            params.require(:name).to_s.strip,
            params[:placement].presence || "popup",
          )
        render json: GuestCta::Dashboard.test_hash(test)
      rescue ActiveRecord::RecordInvalid => e
        render_json_error(e.record)
      end

      def update
        test = GuestCta::Test.find(params[:id])
        if test.ended?
          raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.test_ended")
        end
        if test.update(name: params.require(:name).to_s.strip)
          render json: GuestCta::Dashboard.test_hash(test)
        else
          render_json_error(test)
        end
      end

      def destroy
        test = GuestCta::Test.find(params[:id])
        unless test.draft?
          raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.not_draft")
        end
        test.destroy!
        render json: success_json
      end

      def start
        test = GuestCta::Test.find(params[:id])
        test.start!
        render json: GuestCta::Dashboard.test_hash(test)
      end

      def finish
        test = GuestCta::Test.find(params[:id])
        winner = nil
        if params[:winner_variant_id].present?
          winner = test.variants.find(params[:winner_variant_id])
        end
        test.finish!(winner: winner)
        render json: GuestCta::Dashboard.test_hash(test)
      end
    end
  end
end
