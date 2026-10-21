# discourse-guest-cta-ab

A Discourse plugin that shows three things to logged-out visitors and lets
admins A/B test different versions of each:

- a **call-to-action popup** (replaces the "Guest CTA Gate" theme component),
- a **clickable banner image under the first post** of every topic (replaces the
  banner theme component), and
- a **guest reply**: a message written in Markdown like a normal reply
  (links, images, formatting), shown directly under the first post of every
  topic under a name and profile photo of your choosing.

The popup and banner behave exactly as the components did (same markup and
styles, same frequency cap and close behaviour, no SEO impact). The reply is
rendered in the browser only, like the other two, so crawlers never see it;
every element of it also carries an `ad-reply` class so it can always be told
apart from real posts. What is new:

- **Variants.** Each version is stored server-side. A popup variant has a
  heading, image, subheading, body, button text, link, colours and a delay
  (seconds after page load before it appears, 0 by default so it shows at
  once). The delay is part of the variant, so it can be split tested like
  anything else. A banner variant has a desktop image, an optional mobile
  image, alt text and a link. A reply variant has the name it appears under,
  a profile photo (an image URL or upload) and the message, which is cooked
  on the server with the same Markdown engine as posts.
- **Tests.** A test starts with a frozen copy of the current popup as the
  control, plus any variants you add. Visitors are split evenly at random, and
  each visitor keeps seeing the version they were first shown.
- **Tracking.** The popup reports one impression when it shows and one click
  when the button is pressed. The banner and the reply report an impression
  once they are half visible on screen; the banner a click when it is
  clicked, the reply a click on any link in the message. Counts are stored
  as daily totals per variant.
- **Dashboard.** `Admin → Plugins → Guest CTA tests` has a Popup page, a
  Banner page and a Reply page. Each shows the current version with its
  numbers, the running test with impressions, clicks, CTR, lift and
  confidence per variant (leader highlighted), and a history of past tests.
  The three placements' tests run independently.
- **One-click winner.** "Make this the default" ends the test and copies the
  winning variant onto the current version.
- **Overview panel.** The admin dashboard (`Admin`, the admin homepage) shows a
  "Guest CTA tests" panel with an on/off switch for each of the popup, the
  banner and the reply, plus each placement's current test results or, when
  nothing is running, the current version's numbers. The same switch sits at
  the top of the Popup, Banner and Reply pages.

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
   **Edit** and set the image, alt text and link. On the **Reply** page click
   **Edit**, enter the name and profile photo it appears under and write the
   message.
2. Under `Admin → Settings → Plugins`, switch on `guest cta popup enabled`,
   `guest cta banner enabled` and/or `guest cta reply enabled`. All are off by
   default so nothing generic is ever shown to visitors. The popup's frequency cap, close button
   and background click settings are there too. The delay before the popup
   shows is set on the popup itself (Edit on the Popup page), not here.
3. Disable the old popup and banner theme components (or remove them), so
   nothing shows twice.

## Running a test

1. On the Popup, Banner or Reply page, give the test a name and click **Create
   test**. A draft is created with the control (a copy of the current version).
2. **Add variant** opens an editor pre-filled with the control, with a live
   preview. Change the heading, image, text, colours, delay, alt text, link,
   message or author and save. To test timing alone, keep everything else the same and give
   each variant a different delay (the control keeps the current one). Add as
   many variants as you like.
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
popup, one for the banner, one for the reply).

## How it works

- Logged-out visitors receive the live configuration for every placement
  (baseline plus running test variants) inside the preloaded site data, so
  there is no extra request before anything shows. The anonymous site cache is
  cleared whenever an admin changes anything.
- The reply and the banner are rendered after the first post, in that order,
  through the Glimmer post stream's `post-article` wrapper outlet. An
  impression is counted once the element is at least half visible on screen,
  once per topic per page load.
- The reply's markup mirrors a post (`topic-avatar`, `topic-body`,
  `topic-meta-data`, `names`, `cooked`) so the active theme styles it like
  any other reply, and its Markdown is cooked with `PrettyText.cook`, the same
  sanitiser posts go through. The raw Markdown never leaves the server;
  visitors only receive the cooked HTML. The name is plain text and links
  nowhere; only links inside the message count as clicks.
- Variant assignment and the popup frequency cap live in `localStorage`
  (`guest_cta_assignment`, `guest_cta_banner_assignment`,
  `guest_cta_reply_assignment` and `guest_cta_gate_last_shown`, the latter
  shared with the old theme component).
- Events are posted to `POST /guest-cta/events`, rate limited per IP, and only
  accepted for variants that are live right now.
- Images uploaded through the editor, including those embedded in a reply's
  Markdown, are registered as upload references so Discourse's orphan-upload
  cleanup never removes them.

## Development

Specs live in `spec/` and run with the usual plugin command from a Discourse
checkout:

```bash
LOAD_PLUGINS=1 bin/rspec plugins/discourse-guest-cta-ab/spec
```
