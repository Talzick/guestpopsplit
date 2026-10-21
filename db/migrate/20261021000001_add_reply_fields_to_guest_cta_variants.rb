# frozen_string_literal: true

# Third placement: a "reply" shown under the first post. It is posted under a
# display name and avatar image of the admin's choosing, and the message is
# Markdown (links and images like a normal reply), cooked on save.
class AddReplyFieldsToGuestCtaVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :guest_cta_variants, :reply_name, :string, null: false, default: ""
    add_column :guest_cta_variants, :reply_avatar_url, :string, null: false, default: ""
    add_column :guest_cta_variants, :reply_avatar_upload_id, :integer
    add_column :guest_cta_variants, :reply_raw, :text, null: false, default: ""
    add_column :guest_cta_variants, :reply_cooked, :text, null: false, default: ""
  end
end
