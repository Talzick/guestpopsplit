# discourse-guest-cta-ab

A Discourse plugin that shows two things to logged-out visitors and lets admins
A/B test different versions of each:

- a **call-to-action popup** (replaces the "Guest CTA Gate" theme component), and
- a **clickable banner image under the first post** of every topic (replaces the
  banner theme component).

Both behave exactly as the components did (same markup and styles, same popup
delay, frequency cap and close behaviour, no SEO impact). What is new:

- **Variants.** Each version is stored server-side. A popup variant has a
  heading, image, subheading, body, button text, link and colours. A banner
  variant has a desktop image, an optional mobile image, alt text and a link.
- **Tests.** A test starts with a frozen copy of the current popup as the
  control, plus any variants you add. Visitors are split evenly at random, and
  each visitor keeps seeing the version they were first shown.
- **Tracking.** The popup reports one impression when it shows and one click
  when the button is pressed. Counts are stored as daily totals per variant.
- **Dashboard.** `Admin → Plugins → Guest CTA tests` has a Popup page and a
  Banner page. Each shows the current version with its numbers, the running
  test with impressions, clicks, CTR, lift and confidence per variant (leader
  highlighted), and a history of past tests. Popup and banner tests run
  independently.
- **One-click winner.** "Make this the default" ends the test and copies the
  winning variant onto the current version.

## Install

Add the plugin to your `app.yml` like any other plugin and rebuild:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/<you>/discourse-guest-cta-ab.git
```

Then:

1. Go to `Admin → Plugins → Guest CTA tests`. On the **Popup** page click
   **Edit** and enter your heading, image, text, button and colours (the
   plugin ships with neutral placeholder text). On the **Banner** page click
   **Edit** and set the image, alt text and link.
2. Under `Admin → Settings → Plugins`, switch on `guest cta popup enabled`
   and/or `guest cta banner enabled`. Both are off by default so nothing
   generic is ever shown to visitors. The popup's delay, frequency cap, close
   button and background click settings are there too.
3. Disable the old popup and banner theme components (or remove them), so
   nothing shows twice.

## Running a test

1. On the Popup or Banner page, give the test a name and click **Create
   test**. A draft is created with the control (a copy of the current version).
2. **Add variant** opens an editor pre-filled with the control, with a live
   preview. Change the heading, image, text, colours, alt text or link and
   save. Add as many variants as you like.
3. **Start test.** From now on logged-out visitors are randomly assigned one
   version and the counters run.
4. Watch the results table. CTR is clicks ÷ impressions. "vs control" shows the
   relative lift and a confidence figure from a two-proportion z-test. A result
   is marked with a tick when confidence is above 95% and both versions have
   at least 100 impressions. Treat anything below that as inconclusive.
5. Click **Make this the default** on the version you want. The test ends,
   the current version takes on that content, and the test moves to the
   history with its previews and final numbers. You can also end a test
   without a winner.

Only one draft or running test can exist at a time per placement (one for the
popup, one for the banner).

## How it works

- Logged-out visitors receive the live configuration for both placements
  (baseline plus running test variants) inside the preloaded site data, so
  there is no extra request before anything shows. The anonymous site cache is
  cleared whenever an admin changes anything.
- The banner is rendered after the first post through the Glimmer post
  stream's `post-article` wrapper outlet. An impression is counted once the
  banner is at least half visible on screen, once per topic per page load.
- Variant assignment and the popup frequency cap live in `localStorage`
  (`guest_cta_assignment`, `guest_cta_banner_assignment` and
  `guest_cta_gate_last_shown`, the latter shared with the old theme component).
- Events are posted to `POST /guest-cta/events`, rate limited per IP, and only
  accepted for variants that are live right now.
- Images uploaded through the editor are registered as upload references so
  Discourse's orphan-upload cleanup never removes them.

## Development

Specs live in `spec/` and run with the usual plugin command from a Discourse
checkout:

```bash
LOAD_PLUGINS=1 bin/rspec plugins/discourse-guest-cta-ab/spec
```
