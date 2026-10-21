# frozen_string_literal: true

module GuestCta
  class Variant < ActiveRecord::Base
    self.table_name = "guest_cta_variants"

    # Where a variant is shown. Each placement has its own baseline and tests.
    PLACEMENTS = %w[popup banner reply].freeze

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

    # The reply is written in Markdown and cooked on save; the cooked HTML is
    # part of the content so a winner's copy carries it over unchanged.
    REPLY_FIELDS = %i[reply_name reply_avatar_url reply_raw reply_cooked open_in_new_tab].freeze

    # Reply fields an admin may set directly (the cooked HTML is derived).
    REPLY_EDITABLE_FIELDS = (REPLY_FIELDS - %i[reply_cooked]).freeze

    CONTENT_FIELDS = (POPUP_FIELDS + BANNER_FIELDS + REPLY_FIELDS).uniq.freeze

    # Placeholder seed values for a brand-new install. All placements are
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
      "reply" => {
        reply_name: "",
        reply_avatar_url: "",
        reply_raw: "",
        reply_cooked: "",
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

    # Likewise the reply baseline may stay empty; a tested reply needs the name
    # it is posted under and a message.
    with_options if: -> { reply? && !is_baseline } do
      validates :reply_name, presence: true
      validates :reply_raw, presence: true
    end

    before_validation :default_show_delay
    before_validation :normalize_reply_name, if: :reply?
    before_save :cook_reply, if: :reply?
    before_save :link_image_uploads
    after_save :ensure_upload_references
    after_commit { Site.clear_anon_cache! }

    def self.content_fields_for(placement)
      case placement.to_s
      when "banner"
        BANNER_FIELDS
      when "reply"
        REPLY_FIELDS
      else
        POPUP_FIELDS
      end
    end

    # The fields an admin may submit for a placement.
    def self.editable_fields_for(placement)
      placement.to_s == "reply" ? REPLY_EDITABLE_FIELDS : content_fields_for(placement)
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

    def reply?
      placement == "reply"
    end

    # True when there is something to show visitors. The popup always has a
    # heading; the banner needs an image and the reply a name and a message.
    def configured?
      case placement
      when "banner"
        image_url.present?
      when "reply"
        reply_name.present? && reply_raw.present?
      else
        true
      end
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

    # Shape sent to logged-out visitors (no admin-only fields). The reply's raw
    # Markdown stays on the server; visitors only get the cooked HTML.
    def to_public_h
      h = { id: id }.merge(content_attributes)
      h.delete(:reply_raw) if reply?
      h
    end

    private

    def normalize_reply_name
      self.reply_name = reply_name.to_s.strip
    end

    # Markdown -> sanitised HTML, exactly as a post would be cooked, so the
    # reply supports the same links, images, quotes and formatting.
    def cook_reply
      return unless will_save_change_to_reply_raw? || reply_cooked.blank?
      self.reply_cooked = reply_raw.present? ? PrettyText.cook(reply_raw) : ""
    end

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
      if will_save_change_to_reply_avatar_url?
        self.reply_avatar_upload_id = upload_id_for(reply_avatar_url)
      end
    end

    def upload_id_for(url)
      return nil if url.blank?
      Upload.get_from_url(url)&.id
    rescue StandardError
      nil
    end

    # Images embedded in the reply's Markdown count too.
    def reply_upload_ids
      return [] unless reply? && reply_raw.present?
      Upload.extract_upload_ids(reply_raw)
    rescue StandardError
      []
    end

    def ensure_upload_references
      UploadReference.ensure_exist!(
        upload_ids:
          ([image_upload_id, mobile_image_upload_id, reply_avatar_upload_id] + reply_upload_ids)
            .compact
            .uniq,
        target: self,
      )
    end
  end
end
