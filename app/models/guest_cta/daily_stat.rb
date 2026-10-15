# frozen_string_literal: true

module GuestCta
  class DailyStat < ActiveRecord::Base
    self.table_name = "guest_cta_daily_stats"

    belongs_to :variant, class_name: "GuestCta::Variant"

    EVENTS = %w[impression click].freeze

    # One row per variant per day keeps the table tiny no matter the traffic.
    def self.record!(variant_id, event)
      raise ArgumentError, "unknown event #{event}" unless EVENTS.include?(event)
      column = event == "click" ? "clicks" : "impressions"
      impressions = event == "impression" ? 1 : 0
      clicks = event == "click" ? 1 : 0

      DB.exec(<<~SQL, variant_id: variant_id, date: Time.zone.today, impressions: impressions, clicks: clicks)
        INSERT INTO guest_cta_daily_stats
          (variant_id, date, impressions, clicks, created_at, updated_at)
        VALUES
          (:variant_id, :date, :impressions, :clicks, NOW(), NOW())
        ON CONFLICT (variant_id, date) DO UPDATE
          SET #{column} = guest_cta_daily_stats.#{column} + 1,
              updated_at = NOW()
      SQL
    end
  end
end
