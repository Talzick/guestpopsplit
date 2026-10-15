import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { bannerInnerHtml } from "../../lib/guest-cta/banner-markup";
import { buttonStyle, modalInnerHtml } from "../../lib/guest-cta/popup-markup";

// Renders a variant with the real markup and styles of its placement, inert
// and scaled down. @placement is "popup" or "banner".
export default class VariantPreview extends Component {
  get isBanner() {
    return this.args.placement === "banner";
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

  <template>
    {{#if this.isBanner}}
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
