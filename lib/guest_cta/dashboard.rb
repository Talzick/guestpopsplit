# frozen_string_literal: true

module GuestCta
  # Builds the JSON the admin dashboard renders for one placement.
  module Dashboard
    def self.build(placement)
      placement = placement.to_s
      raise Discourse::InvalidParameters.new(:placement) unless Variant::PLACEMENTS.include?(placement)

      tests = Test.for_placement(placement)
      current = tests.unfinished.order(:id).first
      past = tests.where(status: "ended").order(ended_at: :desc).limit(100)
      {
        placement: placement,
        baseline: Variant.baseline(placement).to_h(with_stats: true),
        current_test: current && test_hash(current),
        past_tests: past.map { |t| test_hash(t) },
      }
    end

    def self.test_hash(test)
      variants = test.variants.to_a
      control = variants.find(&:is_control)
      control_stats = control&.stats

      rows =
        variants.map do |variant|
          row = variant.to_h(with_stats: true)
          if control_stats && !variant.is_control
            row[:significance] = Significance.compare(row[:stats], control_stats)
          end
          row
        end

      leader =
        rows.select { |r| r[:stats][:clicks] > 0 }.max_by { |r| [r[:stats][:ctr], r[:stats][:clicks]] }
      leader[:is_leader] = true if leader

      {
        id: test.id,
        placement: test.placement,
        name: test.name,
        status: test.status,
        started_at: test.started_at,
        ended_at: test.ended_at,
        winner_variant_id: test.winner_variant_id,
        total_impressions: rows.sum { |r| r[:stats][:impressions] },
        total_clicks: rows.sum { |r| r[:stats][:clicks] },
        variants: rows,
      }
    end
  end
end
