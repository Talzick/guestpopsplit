import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import { bannerInnerHtml } from "../../lib/guest-cta/banner-markup";
import { pickVariant, track } from "../../lib/guest-cta/tracking";

const ASSIGNMENT_KEY = "guest_cta_banner_assignment";

// Topics whose banner impression has already been counted this page load,
// so re-renders of the first post do not count twice.
const countedTopics = new Set();

// Rendered after the first post of a topic for logged-out visitors.
export default class PostBanner extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;

  static shouldRender(args, context) {
    const post = args.post || args.outletArgs?.post;
    return !!post && post.post_number === 1 && !context.currentUser;
  }

  get post() {
    return this.args.post || this.args.outletArgs?.post;
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

    const count = () => {
      if (countedTopics.has(topicId)) {
        return;
      }
      countedTopics.add(topicId);
      track(variantId, "impression");
    };

    if (typeof IntersectionObserver === "undefined") {
      count();
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          count();
          observer.disconnect();
        }
      },
      { threshold: 0.5 }
    );
    observer.observe(element);
    return () => observer.disconnect();
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
