# frozen_string_literal: true

# Reply extras: a like count shown under the message, and optional
# category-specific messages (each with its own cooked HTML and button) that
# replace the default message when the topic is in one of those categories.
class AddReplyOptionsToGuestCtaVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :guest_cta_variants, :reply_like_count, :integer, null: false, default: 0
    add_column :guest_cta_variants, :reply_category_overrides, :jsonb, null: false, default: []
  end
end
