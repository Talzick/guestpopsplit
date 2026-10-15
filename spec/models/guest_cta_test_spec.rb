# frozen_string_literal: true

RSpec.describe GuestCta::Test do
  before { SiteSetting.guest_cta_enabled = true }

  it "creates a frozen copy of the baseline as the control" do
    baseline = GuestCta::Variant.baseline("popup")
    baseline.update!(heading: "Original heading")

    test = described_class.create_with_control!("First test", "popup")

    expect(test.status).to eq("draft")
    expect(test.placement).to eq("popup")
    expect(test.variants.count).to eq(1)
    expect(test.control.heading).to eq("Original heading")
    expect(test.control.is_control).to eq(true)

    baseline.update!(heading: "Changed later")
    expect(test.control.reload.heading).to eq("Original heading")
  end

  it "refuses to start with only the control" do
    test = described_class.create_with_control!("Lonely", "popup")
    expect { test.start! }.to raise_error(Discourse::InvalidAccess)
  end

  it "copies the winner onto the baseline when finished" do
    test = described_class.create_with_control!("Headline test", "popup")
    variant =
      test.variants.create!(
        placement: "popup",
        name: "B",
        heading: "Winning heading",
        button_text: "Go",
        button_url: "/x",
      )
    test.start!
    expect(test.reload.running?).to eq(true)

    test.finish!(winner: variant)

    baseline = GuestCta::Variant.baseline("popup")
    expect(baseline.heading).to eq("Winning heading")
    expect(baseline.button_text).to eq("Go")
    expect(baseline.stats_from).to eq(Time.zone.today)
    expect(test.reload.ended?).to eq(true)
    expect(test.winner_variant_id).to eq(variant.id)
  end

  it "leaves the baseline alone when the control wins" do
    GuestCta::Variant.baseline("popup").update!(heading: "Keep me")
    test = described_class.create_with_control!("Control wins", "popup")
    test.variants.create!(placement: "popup", name: "B", heading: "Other", button_text: "Go", button_url: "/x")
    test.start!

    test.finish!(winner: test.control)

    expect(GuestCta::Variant.baseline("popup").heading).to eq("Keep me")
    expect(test.reload.winner_variant_id).to eq(test.control.id)
  end

  it "refuses a banner test until the banner baseline has an image" do
    expect { described_class.create_with_control!("Too early", "banner") }.to raise_error(
      Discourse::InvalidAccess,
    )
  end

  it "keeps popup and banner tests independent" do
    GuestCta::Variant.baseline("banner").update!(image_url: "/uploads/banner.png", alt_text: "Banner")
    popup = described_class.create_with_control!("Popup test", "popup")
    banner = described_class.create_with_control!("Banner test", "banner")

    expect(popup.control.placement).to eq("popup")
    expect(banner.control.placement).to eq("banner")
    expect(banner.control.alt_text).to eq("Banner")

    banner.variants.create!(
      placement: "banner",
      name: "B",
      image_url: "/uploads/other.png",
      alt_text: "Other banner",
      button_url: "/go",
    )
    banner.start!

    expect(GuestCta::LiveConfig.payload[:banner][:test][:id]).to eq(banner.id)
    expect(GuestCta::LiveConfig.payload[:popup][:test]).to be_nil

    winner = banner.variants.last
    banner.finish!(winner: winner)
    expect(GuestCta::Variant.baseline("banner").image_url).to eq("/uploads/other.png")
    expect(GuestCta::Variant.baseline("banner").alt_text).to eq("Other banner")
  end

  it "validates banner variants need an image and alt text" do
    variant = GuestCta::Variant.new(placement: "banner", button_url: "/", name: "x")
    expect(variant).not_to be_valid
    expect(variant.errors[:image_url]).to be_present
    expect(variant.errors[:alt_text]).to be_present
  end
end

RSpec.describe GuestCta::Significance do
  it "returns nil without impressions" do
    expect(described_class.compare({ impressions: 0, clicks: 0 }, { impressions: 10, clicks: 1 })).to be_nil
  end

  it "flags a clear difference as significant" do
    result =
      described_class.compare(
        { impressions: 1000, clicks: 80 },
        { impressions: 1000, clicks: 40 },
      )
    expect(result[:significant]).to eq(true)
    expect(result[:confidence]).to be > 95
    expect(result[:lift]).to eq(100.0)
  end

  it "does not flag noise as significant" do
    result =
      described_class.compare(
        { impressions: 100, clicks: 5 },
        { impressions: 100, clicks: 4 },
      )
    expect(result[:significant]).to eq(false)
  end
end
