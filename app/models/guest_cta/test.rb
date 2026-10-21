# frozen_string_literal: true

module GuestCta
  class Test < ActiveRecord::Base
    self.table_name = "guest_cta_tests"

    STATUSES = %w[draft running ended].freeze

    has_many :variants,
             -> { order(:id) },
             class_name: "GuestCta::Variant",
             foreign_key: :test_id,
             dependent: :destroy
    belongs_to :winner_variant, class_name: "GuestCta::Variant", optional: true

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :placement, inclusion: { in: Variant::PLACEMENTS }

    scope :running, -> { where(status: "running") }
    scope :unfinished, -> { where(status: %w[draft running]) }
    scope :for_placement, ->(placement) { where(placement: placement.to_s) }

    after_commit { Site.clear_anon_cache! }

    def draft?
      status == "draft"
    end

    def running?
      status == "running"
    end

    def ended?
      status == "ended"
    end

    def control
      variants.find(&:is_control)
    end

    # A new test always starts with a frozen copy of the current baseline as
    # its control, so the history keeps showing exactly what was tested even
    # after the baseline changes.
    def self.create_with_control!(name, placement)
      placement = placement.to_s
      raise Discourse::InvalidParameters.new(:placement) unless Variant::PLACEMENTS.include?(placement)

      transaction do
        if for_placement(placement).unfinished.exists?
          raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.test_already_open")
        end
        baseline = Variant.baseline(placement)
        unless baseline.configured?
          raise Discourse::InvalidAccess.new(
                  nil,
                  nil,
                  custom_message: "guest_cta.errors.#{placement}_not_configured",
                )
        end
        test = create!(name: name, placement: placement, status: "draft")
        test.variants.create!(
          baseline.content_attributes.merge(
            placement: placement,
            name: I18n.t("guest_cta.control_name"),
            is_control: true,
          ),
        )
        test
      end
    end

    def start!
      raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.not_draft") unless draft?
      if variants.count < 2
        raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.need_two_variants")
      end
      if Test.for_placement(placement).running.where.not(id: id).exists?
        raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.another_running")
      end
      update!(status: "running", started_at: Time.zone.now)
    end

    # Ends the test. When a non-control winner is given, its content becomes the
    # new baseline and the baseline's stats start fresh from today.
    def finish!(winner: nil)
      raise Discourse::InvalidAccess.new(nil, nil, custom_message: "guest_cta.errors.not_running") unless running?
      transaction do
        if winner
          raise Discourse::InvalidParameters.new(:winner_variant_id) if winner.test_id != id
          unless winner.is_control
            Variant.baseline(placement).update!(
              winner.content_attributes.merge(stats_from: Time.zone.today),
            )
          end
        end
        update!(status: "ended", ended_at: Time.zone.now, winner_variant_id: winner&.id)
      end
    end
  end
end
