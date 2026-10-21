import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import {
  adReplyInnerHtml,
  resolveReplyMessage,
} from "../../lib/guest-cta/ad-reply-markup";
import {
  observeImpression,
  pickVariant,
  track,
} from "../../lib/guest-cta/tracking";

const ASSIGNMENT_KEY = "guest_cta_reply_assignment";

// Topics whose reply impression has already been counted this page load.
const countedTopics = new Set();

// A message styled like a reply, shown directly under the first
// post of a topic to logged-out visitors. Rendered only in the browser, so
// crawlers never see it; everything carries `ad-reply` classes in case one
// renders the page anyway.
export default class AdReply extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;

  get post() {
    return this.args.post;
  }

  get config() {
    return this.site.guest_cta?.reply;
  }

  get enabled() {
    return (
      this.siteSettings.guest_cta_enabled &&
      this.siteSettings.guest_cta_reply_enabled &&
      !this.currentUser &&
      this.post?.post_number === 1 &&
      !!this.variant?.reply_name &&
      !!this.message.reply_cooked
    );
  }

  // The topic's category and its parent, so a message set for a parent
  // category also applies to topics in its subcategories.
  get categoryIds() {
    const categoryId = this.post?.topic?.category_id ?? this.post?.category_id;
    if (!categoryId) {
      return [null, null];
    }
    const category = (this.site.categories || []).find(
      (c) => c.id === categoryId
    );
    return [categoryId, category?.parent_category_id ?? null];
  }

  get message() {
    if (!this.variant) {
      return { reply_cooked: "" };
    }
    return resolveReplyMessage(this.variant, ...this.categoryIds);
  }

  get variant() {
    if (!this.config?.baseline) {
      return null;
    }
    return pickVariant(this.config, ASSIGNMENT_KEY);
  }

  get markup() {
    return htmlSafe(adReplyInnerHtml(this.variant, this.message));
  }

  // Counts an impression once the reply is actually on screen, once per topic
  // per page load, and applies the new-tab option to the message's links and
  // button.
  setup = modifier((element) => {
    if (this.variant.open_in_new_tab) {
      element.querySelectorAll(".ad-reply__contents a[href]").forEach((link) => {
        link.target = "_blank";
        link.rel = "noopener";
      });
    }

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

  // Any link inside the message, and the button, counts as a click; the
  // author line and the like count do not.
  @action
  onClick(event) {
    if (event.target.closest(".ad-reply__contents a[href]")) {
      track(this.variant.id, "click");
    }
  }

  <template>
    {{#if this.enabled}}
      <div
        class="ad-reply"
        data-ad-reply="true"
        {{this.setup}}
        {{on "click" this.onClick}}
      >
        <div class="ad-reply__article">
          <div class="ad-reply__row">
            {{this.markup}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
