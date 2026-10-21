import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { adReplyInnerHtml } from "../../lib/guest-cta/ad-reply-markup";
import { bannerInnerHtml } from "../../lib/guest-cta/banner-markup";
import { buttonStyle, modalInnerHtml } from "../../lib/guest-cta/popup-markup";

// Renders a variant with the real markup and styles of its placement, inert
// and scaled down. @placement is "popup", "banner" or "reply". For the reply,
// @message (see resolveReplyMessage) picks which message to show; it defaults
// to the variant's default message.
export default class VariantPreview extends Component {
  get isBanner() {
    return this.args.placement === "banner";
  }

  get isReply() {
    return this.args.placement === "reply";
  }

  get popupMarkup() {
    return htmlSafe(
      modalInnerHtml(this.args.variant, { showClose: true, preview: true })
    );
  }

  get popupStyle() {
    return htmlSafe(buttonStyle(this.args.variant));
  }

  get bannerMarkup() {
    return htmlSafe(bannerInnerHtml(this.args.variant));
  }

  get replyMarkup() {
    return htmlSafe(
      adReplyInnerHtml(this.args.variant, this.args.message || null, {
        preview: true,
      })
    );
  }

  <template>
    {{#if this.isReply}}
      <div
        class="ad-reply-preview {{if @small 'ad-reply-preview--small'}}"
        ...attributes
      >
        <div class="ad-reply ad-reply--preview">
          <div class="ad-reply__article">
            <div class="ad-reply__row">{{this.replyMarkup}}</div>
          </div>
        </div>
      </div>
    {{else if this.isBanner}}
      <div
        class="gcb-preview {{if @small 'gcb-preview--small'}}"
        ...attributes
      >
        <div class="gcb-banner gcb-banner--preview">
          <span class="gcb-link">{{this.bannerMarkup}}</span>
        </div>
      </div>
    {{else}}
      <div
        class="gcg-preview {{if @small 'gcg-preview--small'}}"
        ...attributes
      >
        <div class="gcg-modal gcg-modal--preview" style={{this.popupStyle}}>
          {{this.popupMarkup}}
        </div>
      </div>
    {{/if}}
  </template>
}
