# frozen_string_literal: true

# The popup delay used to be a single site setting. It now lives on each
# popup variant so it can be A/B tested like any other part of the popup.
class AddShowDelayToGuestCtaVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :guest_cta_variants, :show_delay_seconds, :float, null: false, default: 0.0
  end
end
