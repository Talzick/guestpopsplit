import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import { bannerInnerHtml } from "../../lib/guest-cta/banner-markup";
import {
  observeImpression,
  pickVariant,
  track,
} from "../../lib/guest-cta/tracking";

const ASSIGNMENT_KEY = "guest_cta_banner_assignment";

// Topics whose banner impression has already been counted this page load,
// so re-renders of the first post do not count twice.
const countedTopics = new Set();

// Rendered after the first post of a topic for logged-out visitors (see
// after-first-post.gjs, which places it together with the guest reply).
export default class PostBanner extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;

  get post() {
    return this.args.post;
  }

  get config() {
    return this.site.guest_cta?.banner;
  }

  get enabled() {
    return (
      this.siteSettings.guest_cta_enabled &&
      this.siteSettings.guest_cta_banner_enabled &&
      !this.currentUser &&
      this.post?.post_number === 1 &&
      !!this.config?.baseline?.image_url
    );
  }

  get variant() {
    return pickVariant(this.config, ASSIGNMENT_KEY);
  }

  get markup() {
    return htmlSafe(bannerInnerHtml(this.variant));
  }

  get href() {
    return this.variant.button_url || "/";
  }

  get target() {
    return this.variant.open_in_new_tab ? "_blank" : null;
  }

  get rel() {
    return this.variant.open_in_new_tab ? "noopener" : null;
  }

  // Counts an impression once the banner is actually on screen (at least
  // half visible), once per topic per page load.
  countImpression = modifier((element) => {
    const topicId = this.post?.topic_id ?? this.post?.id;
    const variantId = this.variant.id;
    if (countedTopics.has(topicId)) {
      return;
    }

    return observeImpression(element, () => {
      if (countedTopics.has(topicId)) {
        return;
      }
      countedTopics.add(topicId);
      track(variantId, "impression");
    });
  });

  @action
  onClick() {
    track(this.variant.id, "click");
  }

  <template>
    {{#if this.enabled}}
      <div class="gcb-banner" {{this.countImpression}}>
        <a
          class="gcb-link"
          href={{this.href}}
          target={{this.target}}
          rel={{this.rel}}
          {{on "click" this.onClick}}
        >
          {{this.markup}}
        </a>
      </div>
    {{/if}}
  </template>
}
