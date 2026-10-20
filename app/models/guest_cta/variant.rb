# frozen_string_literal: true

module GuestCta
  class Variant < ActiveRecord::Base
    self.table_name = "guest_cta_variants"

    # Where a variant is shown. Each placement has its own baseline and tests.
    PLACEMENTS = %w[popup banner].freeze

    # Everything a visitor can see, per placement. These are the fields copied
    # onto the baseline when a test winner is confirmed.
    POPUP_FIELDS = %i[
      heading
      image_url
      image_max_width_px
      subheading
      body_text
      button_text
      button_url
      button_color
      button_text_color
      button_glow
      open_in_new_tab
      show_delay_seconds
    ].freeze

    BANNER_FIELDS = %i[image_url mobile_image_url alt_text button_url open_in_new_tab].freeze

    CONTENT_FIELDS = (POPUP_FIELDS + BANNER_FIELDS).uniq.freeze

    # Placeholder seed values for a brand-new install. Both placements are
    # switched off by default, so admins fill these in before anything shows.
    DEFAULT_CONTENT = {
      "popup" => {
        heading: "Your headline goes here",
        image_url: "",
        image_max_width_px: 220,
        subheading: "A short supporting line",
        body_text: "Tell visitors what they get when they click the button.",
        button_text: "Learn more",
        button_url: "/",
        button_color: "#e0113b",
        button_text_color: "#ffffff",
        button_glow: true,
        open_in_new_tab: false,
        show_delay_seconds: 0.0,
      },
      "banner" => {
        image_url: "",
        mobile_image_url: "",
        alt_text: "",
        button_url: "/",
        open_in_new_tab: false,
      },
    }.freeze

    belongs_to :test, class_name: "GuestCta::Test", optional: true
    has_many :daily_stats,
             class_name: "GuestCta::DailyStat",
             foreign_key: :variant_id,
             dependent: :delete_all

    validates :placement, inclusion: { in: PLACEMENTS }
    validates :button_url, presence: true
    validates :image_max_width_px,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 40,
                less_than_or_equal_to: 600,
              }
    validates :button_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }
    validates :button_text_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }

    with_options if: :popup? do
      validates :heading, presence: true
      validates :button_text, presence: true
      # Seconds after page load before the popup appears; 0 shows it at once.
      validates :show_delay_seconds,
                numericality: {
                  greater_than_or_equal_to: 0,
                  less_than_or_equal_to: 300,
                }
    end

    # The banner baseline may stay empty (then no banner is shown); every
    # tested variant needs an image and alt text.
    with_options if: -> { banner? && !is_baseline } do
      validates :image_url, presence: true
      validates :alt_text, presence: true
    end

    before_validation :default_show_delay
    before_save :link_image_uploads
    after_save :ensure_upload_references
    after_commit { Site.clear_anon_cache! }

    def self.content_fields_for(placement)
      placement.to_s == "banner" ? BANNER_FIELDS : POPUP_FIELDS
    end

    def self.baseline(placement)
      placement = placement.to_s
      raise Discourse::InvalidParameters.new(:placement) unless PLACEMENTS.include?(placement)
      where(placement: placement, is_baseline: true).first ||
        create!(DEFAULT_CONTENT[placement].merge(placement: placement, name: "Baseline", is_baseline: true))
    end

    def popup?
      placement == "popup"
    end

    def banner?
      placement == "banner"
    end

    def content_fields
      self.class.content_fields_for(placement)
    end

    def content_attributes
      attributes.slice(*content_fields.map(&:to_s)).symbolize_keys
    end

    def stats
      scope = daily_stats
      scope = scope.where("date >= ?", stats_from) if stats_from
      impressions = scope.sum(:impressions).to_i
      clicks = scope.sum(:clicks).to_i
      {
        impressions: impressions,
        clicks: clicks,
        ctr: impressions > 0 ? (clicks * 100.0 / impressions).round(2) : 0.0,
      }
    end

    # Shape sent to the admin dashboard.
    def to_h(with_stats: false)
      h = {
        id: id,
        placement: placement,
        test_id: test_id,
        name: name,
        is_baseline: is_baseline,
        is_control: is_control,
        stats_from: stats_from,
        updated_at: updated_at,
      }.merge(content_attributes)
      h[:stats] = stats if with_stats
      h
    end

    # Shape sent to logged-out visitors (no admin-only fields).
    def to_public_h
      { id: id }.merge(content_attributes)
    end

    private

    # A cleared delay field in the editor means "show at once".
    def default_show_delay
      self.show_delay_seconds = 0.0 if show_delay_seconds.nil?
    end

    # If an image lives in this forum's uploads, remember the upload so the
    # orphan-upload cleanup job never deletes it.
    def link_image_uploads
      self.image_upload_id = upload_id_for(image_url) if will_save_change_to_image_url?
      if will_save_change_to_mobile_image_url?
        self.mobile_image_upload_id = upload_id_for(mobile_image_url)
      end
    end

    def upload_id_for(url)
      return nil if url.blank?
      Upload.get_from_url(url)&.id
    rescue StandardError
      nil
    end

    def ensure_upload_references
      UploadReference.ensure_exist!(
        upload_ids: [image_upload_id, mobile_image_upload_id].compact,
        target: self,
      )
    end
  end
end
