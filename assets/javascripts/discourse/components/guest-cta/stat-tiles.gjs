import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import { formatNumber, formatPercent } from "../../lib/guest-cta/format";

export default class StatTiles extends Component {
  get impressions() {
    return formatNumber(this.args.stats?.impressions);
  }

  get clicks() {
    return formatNumber(this.args.stats?.clicks);
  }

  get ctr() {
    return formatPercent(this.args.stats?.ctr);
  }

  <template>
    <div class="guest-cta-tiles" ...attributes>
      <div class="guest-cta-tile">
        <span class="guest-cta-tile__value">{{this.impressions}}</span>
        <span class="guest-cta-tile__label">{{i18n
            "guest_cta.admin.impressions"
          }}</span>
      </div>
      <div class="guest-cta-tile">
        <span class="guest-cta-tile__value">{{this.clicks}}</span>
        <span class="guest-cta-tile__label">{{i18n
            "guest_cta.admin.clicks"
          }}</span>
      </div>
      <div class="guest-cta-tile guest-cta-tile--ctr">
        <span class="guest-cta-tile__value">{{this.ctr}}</span>
        <span class="guest-cta-tile__label">{{i18n "guest_cta.admin.ctr"}}</span>
      </div>
    </div>
  </template>
}
