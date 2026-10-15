# frozen_string_literal: true

class CreateGuestCtaTables < ActiveRecord::Migration[7.1]
  def change
    create_table :guest_cta_tests do |t|
      t.string :placement, null: false, default: "popup"
      t.string :name, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :winner_variant_id
      t.timestamps
    end
    add_index :guest_cta_tests, %i[placement status]

    create_table :guest_cta_variants do |t|
      t.string :placement, null: false, default: "popup"
      t.integer :test_id
      t.string :name, null: false, default: ""
      t.boolean :is_baseline, null: false, default: false
      t.boolean :is_control, null: false, default: false
      # Popup fields
      t.string :heading, null: false, default: ""
      t.string :subheading, null: false, default: ""
      t.text :body_text, null: false, default: ""
      t.string :button_text, null: false, default: ""
      t.string :button_color, null: false, default: "#e0113b"
      t.string :button_text_color, null: false, default: "#ffffff"
      t.boolean :button_glow, null: false, default: true
      t.integer :image_max_width_px, null: false, default: 220
      # Shared fields (popup image / banner desktop image, button link / banner link)
      t.string :image_url, null: false, default: ""
      t.integer :image_upload_id
      t.string :button_url, null: false, default: "/"
      t.boolean :open_in_new_tab, null: false, default: false
      # Banner fields
      t.string :mobile_image_url, null: false, default: ""
      t.integer :mobile_image_upload_id
      t.string :alt_text, null: false, default: ""
      t.date :stats_from
      t.timestamps
    end
    add_index :guest_cta_variants, :test_id
    add_index :guest_cta_variants, %i[placement is_baseline], unique: true, where: "is_baseline"

    create_table :guest_cta_daily_stats do |t|
      t.integer :variant_id, null: false
      t.date :date, null: false
      t.integer :impressions, null: false, default: 0
      t.integer :clicks, null: false, default: 0
      t.timestamps
    end
    add_index :guest_cta_daily_stats, %i[variant_id date], unique: true
  end
end
