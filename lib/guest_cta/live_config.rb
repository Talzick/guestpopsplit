# frozen_string_literal: true

module GuestCta
  # What logged-out visitors receive, per placement: the baseline plus, while
  # a test is running, the test's variants. The browser picks a variant at
  # random and pins it in localStorage so a visitor always sees the same one.
  module LiveConfig
    def self.payload
      Variant::PLACEMENTS.each_with_object({}) do |placement, result|
        result[placement.to_sym] = placement_payload(placement)
      end
    end

    def self.placement_payload(placement)
      baseline = Variant.baseline(placement)
      test = Test.for_placement(placement).running.first
      {
        baseline: baseline.to_public_h,
        test: (test ? { id: test.id, variants: test.variants.map(&:to_public_h) } : nil),
      }
    end

    # Variant ids the events endpoint will accept right now.
    def self.live_variant_ids
      Variant::PLACEMENTS.flat_map do |placement|
        ids = [Variant.baseline(placement).id]
        test = Test.for_placement(placement).running.first
        ids.concat(test.variants.pluck(:id)) if test
        ids
      end
    end
  end
end
