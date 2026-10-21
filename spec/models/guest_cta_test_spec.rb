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

  it "defaults the popup delay to 0 and copies a tested delay onto the baseline" do
    baseline = GuestCta::Variant.baseline("popup")
    expect(baseline.show_delay_seconds).to eq(0.0)
    expect(GuestCta::LiveConfig.payload[:popup][:baseline][:show_delay_seconds]).to eq(0.0)

    test = described_class.create_with_control!("Delay test", "popup")
    expect(test.control.show_delay_seconds).to eq(0.0)
    delayed =
      test.variants.create!(
        placement: "popup",
        name: "5s",
        heading: "Same heading",
        button_text: "Go",
        button_url: "/x",
        show_delay_seconds: 5,
      )
    test.start!
    expect(GuestCta::LiveConfig.payload[:popup][:test][:variants].last[:show_delay_seconds]).to eq(5.0)

    test.finish!(winner: delayed)
    expect(GuestCta::Variant.baseline("popup").show_delay_seconds).to eq(5.0)
  end

  it "rejects a negative or absurd popup delay" do
    variant = GuestCta::Variant.new(placement: "popup", heading: "x", button_text: "x", button_url: "/")
    variant.show_delay_seconds = -1
    expect(variant).not_to be_valid
    variant.show_delay_seconds = 301
    expect(variant).not_to be_valid
    variant.show_delay_seconds = 2.5
    expect(variant).to be_valid
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

RSpec.describe "GuestCta reply placement" do
  before { SiteSetting.guest_cta_enabled = true }

  it "starts empty and counts as not configured" do
    baseline = GuestCta::Variant.baseline("reply")
    expect(baseline.reply_raw).to eq("")
    expect(baseline.configured?).to eq(false)
    expect { GuestCta::Test.create_with_control!("Too early", "reply") }.to raise_error(
      Discourse::InvalidAccess,
    )
  end

  it "cooks the message like a post and keeps the raw Markdown off the public payload" do
    baseline = GuestCta::Variant.baseline("reply")
    baseline.update!(
      reply_name: "  Chris ",
      reply_avatar_url: "https://example.com/chris.png",
      reply_raw: "Try the **free reading** [here](https://example.com/go).",
    )

    expect(baseline.reply_name).to eq("Chris")
    expect(baseline.reply_cooked).to include("<strong>free reading</strong>")
    expect(baseline.reply_cooked).to include('href="https://example.com/go"')

    public_h = GuestCta::LiveConfig.payload[:reply][:baseline]
    expect(public_h[:reply_cooked]).to include("<strong>free reading</strong>")
    expect(public_h[:reply_name]).to eq("Chris")
    expect(public_h[:reply_avatar_url]).to eq("https://example.com/chris.png")
    expect(public_h).not_to have_key(:reply_raw)
  end

  it "strips scripts from the message" do
    baseline = GuestCta::Variant.baseline("reply")
    baseline.update!(reply_name: "Chris", reply_raw: "Hi <script>alert(1)</script> there")
    expect(baseline.reply_cooked).not_to include("<script")
    expect(baseline.reply_cooked).to include("Hi")
  end

  it "requires a name and a message on tested variants but not on the baseline" do
    baseline = GuestCta::Variant.baseline("reply")
    expect(baseline).to be_valid

    variant = GuestCta::Variant.new(placement: "reply", name: "x", reply_name: "", reply_raw: "")
    expect(variant).not_to be_valid
    expect(variant.errors[:reply_name]).to be_present
    expect(variant.errors[:reply_raw]).to be_present
  end

  it "runs a reply test independently and copies the winner onto the baseline" do
    GuestCta::Variant.baseline("reply").update!(reply_name: "Chris", reply_raw: "Original message")
    test = GuestCta::Test.create_with_control!("Reply test", "reply")
    expect(test.control.reply_cooked).to include("Original message")

    variant =
      test.variants.create!(
        placement: "reply",
        name: "B",
        reply_name: "The TFC Team",
        reply_raw: "Better message with a [link](/go)",
      )
    expect(variant.reply_cooked).to include('href="/go"')
    test.start!

    expect(GuestCta::LiveConfig.payload[:reply][:test][:id]).to eq(test.id)
    expect(GuestCta::LiveConfig.payload[:popup][:test]).to be_nil
    expect(GuestCta::LiveConfig.payload[:banner][:test]).to be_nil
    expect(GuestCta::LiveConfig.live_variant_ids).to include(variant.id)

    test.finish!(winner: variant)
    baseline = GuestCta::Variant.baseline("reply")
    expect(baseline.reply_name).to eq("The TFC Team")
    expect(baseline.reply_raw).to eq("Better message with a [link](/go)")
    expect(baseline.reply_cooked).to include('href="/go"')
  end
end
