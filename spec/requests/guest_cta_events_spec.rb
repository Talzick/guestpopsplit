# frozen_string_literal: true

RSpec.describe GuestCta::EventsController do
  before { SiteSetting.guest_cta_enabled = true }

  let(:baseline) { GuestCta::Variant.baseline("popup") }
  let(:banner_baseline) { GuestCta::Variant.baseline("banner") }

  it "counts impressions and clicks for the live baselines" do
    post "/guest-cta/events.json", params: { variant_id: baseline.id, event: "impression" }
    expect(response.status).to eq(200)
    post "/guest-cta/events.json", params: { variant_id: baseline.id, event: "impression" }
    post "/guest-cta/events.json", params: { variant_id: baseline.id, event: "click" }
    post "/guest-cta/events.json", params: { variant_id: banner_baseline.id, event: "impression" }

    stats = baseline.stats
    expect(stats[:impressions]).to eq(2)
    expect(stats[:clicks]).to eq(1)
    expect(stats[:ctr]).to eq(50.0)
    expect(banner_baseline.stats[:impressions]).to eq(1)
  end

  it "rejects unknown events and variants that are not live" do
    post "/guest-cta/events.json", params: { variant_id: baseline.id, event: "hover" }
    expect(response.status).to eq(400)

    post "/guest-cta/events.json", params: { variant_id: baseline.id + 999, event: "click" }
    expect(response.status).to eq(404)
  end

  it "does nothing when the plugin is disabled" do
    SiteSetting.guest_cta_enabled = false
    post "/guest-cta/events.json", params: { variant_id: baseline.id, event: "impression" }
    expect(response.status).to eq(404)
  end
end

RSpec.describe "Guest CTA admin dashboard" do
  fab!(:admin)

  before do
    SiteSetting.guest_cta_enabled = true
    sign_in(admin)
  end

  it "returns the baseline and no current test per placement" do
    get "/guest-cta/admin/dashboard.json", params: { placement: "popup" }
    expect(response.status).to eq(200)
    json = response.parsed_body
    expect(json["placement"]).to eq("popup")
    expect(json["baseline"]["is_baseline"]).to eq(true)
    expect(json["current_test"]).to be_nil
    expect(json["past_tests"]).to eq([])

    get "/guest-cta/admin/dashboard.json", params: { placement: "banner" }
    expect(response.status).to eq(200)
    expect(response.parsed_body["placement"]).to eq("banner")
    expect(response.parsed_body["baseline"]["image_url"]).to eq("")
  end

  it "runs a popup test end to end" do
    post "/guest-cta/admin/tests.json", params: { name: "Headline", placement: "popup" }
    expect(response.status).to eq(200)
    test_id = response.parsed_body["id"]

    post "/guest-cta/admin/variants.json",
         params: {
           test_id: test_id,
           variant: {
             name: "B",
             heading: "New heading",
             button_text: "Go",
             button_url: "/go",
           },
         }
    expect(response.status).to eq(200)
    variant_id = response.parsed_body["id"]

    put "/guest-cta/admin/tests/#{test_id}/start.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["status"]).to eq("running")

    # Guests now get the test in the site payload.
    expect(GuestCta::LiveConfig.payload[:popup][:test][:variants].map { |v| v[:id] }).to include(variant_id)

    put "/guest-cta/admin/tests/#{test_id}/finish.json", params: { winner_variant_id: variant_id }
    expect(response.status).to eq(200)
    expect(GuestCta::Variant.baseline("popup").heading).to eq("New heading")

    get "/guest-cta/admin/dashboard.json", params: { placement: "popup" }
    expect(response.parsed_body["current_test"]).to be_nil
    expect(response.parsed_body["past_tests"].first["winner_variant_id"]).to eq(variant_id)
  end

  it "edits the banner baseline" do
    put "/guest-cta/admin/baseline.json",
        params: {
          placement: "banner",
          variant: {
            image_url: "/uploads/new-banner.png",
            alt_text: "New banner",
            button_url: "/offer",
          },
        }
    expect(response.status).to eq(200)
    baseline = GuestCta::Variant.baseline("banner")
    expect(baseline.image_url).to eq("/uploads/new-banner.png")
    expect(baseline.alt_text).to eq("New banner")
    expect(baseline.button_url).to eq("/offer")
  end
end
