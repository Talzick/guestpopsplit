# frozen_string_literal: true

module GuestCta
  # Two-proportion z-test: is this variant's click-through rate really
  # different from the control's, or is the gap just noise?
  module Significance
    MIN_IMPRESSIONS = 100

    # Returns nil when there is not enough data to say anything.
    def self.compare(variant_stats, control_stats)
      n1 = variant_stats[:impressions]
      n2 = control_stats[:impressions]
      return nil if n1 == 0 || n2 == 0

      c1 = variant_stats[:clicks]
      c2 = control_stats[:clicks]
      p1 = c1.to_f / n1
      p2 = c2.to_f / n2
      pooled = (c1 + c2).to_f / (n1 + n2)
      se = Math.sqrt(pooled * (1 - pooled) * (1.0 / n1 + 1.0 / n2))
      return nil if se == 0

      z = (p1 - p2) / se
      p_value = Math.erfc(z.abs / Math.sqrt(2)) # two-tailed
      {
        z: z.round(3),
        p_value: p_value.round(4),
        confidence: ((1 - p_value) * 100).round(1),
        significant: p_value < 0.05 && n1 >= MIN_IMPRESSIONS && n2 >= MIN_IMPRESSIONS,
        lift: p2 > 0 ? ((p1 - p2) / p2 * 100).round(1) : nil,
      }
    end
  end
end
