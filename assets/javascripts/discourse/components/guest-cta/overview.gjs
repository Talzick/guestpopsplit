import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  formatDate,
  formatNumber,
  formatPercent,
  formatSignedPercent,
} from "../../lib/guest-cta/format";
import {
  placementEnabled,
  setPlacementEnabled,
} from "../../lib/guest-cta/settings";
import StatTiles from "./stat-tiles";

// The plugin name doubles as the plugin_id segment of the admin plugin routes.
const PLUGIN_ID = "discourse-guest-cta-ab";

const PLACEMENTS = [
  {
    placement: "popup",
    titleKey: "guest_cta.admin.nav_popup",
    route: "adminPlugins.show.guest-cta-ab-dashboard",
  },
  {
    placement: "banner",
    titleKey: "guest_cta.admin.nav_banner",
    route: "adminPlugins.show.guest-cta-ab-banner",
  },
];

// Both placements at a glance: an on/off switch each, plus the current test's
// results or, when nothing is running, the current version's numbers. Shown
// on the admin dashboard (the admin homepage).
export default class GuestCtaOverview extends Component {
  @service siteSettings;

  @tracked data = null;
  @tracked loading = false;
  @tracked loadError = false;
  @tracked saving = null;

  constructor() {
    super(...arguments);
    this.load();
  }

  @action
  async load() {
    this.loading = true;
    this.loadError = false;
    try {
      this.data = await ajax("/guest-cta/admin/overview.json");
    } catch {
      this.loadError = true;
    } finally {
      this.loading = false;
    }
  }

  @action
  async toggle(placement) {
    const next = !placementEnabled(this.siteSettings, placement);
    this.saving = placement;
    try {
      await setPlacementEnabled(this.siteSettings, placement, next);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = null;
    }
  }

  get rows() {
    return PLACEMENTS.map((def) => this.describe(def));
  }

  describe({ placement, titleKey, route }) {
    const info = this.data?.[placement];
    const test = info?.current_test;
    const enabled = placementEnabled(this.siteSettings, placement);
    const running = test?.status === "running";

    let testNote = null;
    if (test) {
      testNote = running
        ? i18n("guest_cta.admin.overview.running_note", {
            date: formatDate(test.started_at),
            impressions: formatNumber(test.total_impressions),
            clicks: formatNumber(test.total_clicks),
          })
        : i18n("guest_cta.admin.overview.draft_note", {
            count: (test.variants || []).length,
          });
    }

    return {
      placement,
      route,
      title: i18n(titleKey),
      enabled,
      stateLabel: i18n(
        enabled
          ? "guest_cta.admin.overview.shown"
          : "guest_cta.admin.overview.hidden",
      ),
      baseline: info?.baseline,
      test,
      running,
      statusLabel: i18n(
        running
          ? "guest_cta.admin.status_running"
          : "guest_cta.admin.status_draft",
      ),
      testNote,
      variants: running ? this.variantRows(test) : [],
    };
  }

  variantRows(test) {
    return (test.variants || []).map((variant) => {
      const sig = variant.significance;
      return {
        name: variant.name,
        isControl: variant.is_control,
        isLeader: !!variant.is_leader,
        impressions: formatNumber(variant.stats?.impressions),
        clicks: formatNumber(variant.stats?.clicks),
        ctr: formatPercent(variant.stats?.ctr),
        lift: sig ? formatSignedPercent(sig.lift) : null,
        confidence: sig ? `${sig.confidence}%` : null,
        significant: !!sig?.significant,
      };
    });
  }

  <template>
    <section class="guest-cta-overview" ...attributes>
      <div class="guest-cta-overview__header">
        <div>
          <h3>{{i18n "guest_cta.admin.overview.title"}}</h3>
          <p class="guest-cta-muted">{{i18n
              "guest_cta.admin.overview.description"
            }}</p>
        </div>
        <DButton
          @action={{this.load}}
          @icon="rotate"
          @title="guest_cta.admin.refresh"
          @isLoading={{this.loading}}
          class="btn-flat btn-small"
        />
      </div>

      {{#if this.loadError}}
        <div class="alert alert-error">{{i18n
            "guest_cta.admin.overview.load_error"
          }}</div>
      {{/if}}

      <div class="guest-cta-overview__grid">
        {{#each this.rows as |row|}}
          <div
            class="guest-cta-overview__placement
              {{unless row.enabled 'guest-cta-overview__placement--off'}}"
          >
            <div class="guest-cta-overview__placement-header">
              <DToggleSwitch
                @state={{row.enabled}}
                @translatedLabel={{row.title}}
                disabled={{eq this.saving row.placement}}
                {{on "click" (fn this.toggle row.placement)}}
              />
              <span
                class="guest-cta-overview__state
                  {{if
                    row.enabled
                    'guest-cta-overview__state--on'
                    'guest-cta-overview__state--off'
                  }}"
              >
                {{row.stateLabel}}
              </span>
              <LinkTo
                @route={{row.route}}
                @model={{PLUGIN_ID}}
                class="guest-cta-overview__manage"
              >
                {{i18n "guest_cta.admin.overview.manage"}}
                {{icon "chevron-right"}}
              </LinkTo>
            </div>

            {{#if row.test}}
              <div class="guest-cta-overview__test">
                <span
                  class="guest-cta-badge guest-cta-badge--{{row.test.status}}"
                >
                  {{row.statusLabel}}
                </span>
                <strong>{{row.test.name}}</strong>
                <span class="guest-cta-muted">{{row.testNote}}</span>
              </div>
            {{/if}}

            {{#if row.running}}
              <table class="guest-cta-overview__variants">
                <thead>
                  <tr>
                    <th>{{i18n "guest_cta.admin.variant"}}</th>
                    <th class="guest-cta-overview__num">{{i18n
                        "guest_cta.admin.impressions"
                      }}</th>
                    <th class="guest-cta-overview__num">{{i18n
                        "guest_cta.admin.clicks"
                      }}</th>
                    <th class="guest-cta-overview__num">{{i18n
                        "guest_cta.admin.ctr"
                      }}</th>
                    <th class="guest-cta-overview__num">{{i18n
                        "guest_cta.admin.vs_control"
                      }}</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each row.variants as |v|}}
                    <tr
                      class={{if v.isLeader "guest-cta-overview__row--leader"}}
                    >
                      <td>
                        {{v.name}}
                        {{#if v.isControl}}
                          <span
                            class="guest-cta-badge guest-cta-badge--control"
                          >{{i18n "guest_cta.admin.control"}}</span>
                        {{else if v.isLeader}}
                          <span
                            class="guest-cta-badge guest-cta-badge--leader"
                          >{{icon "trophy"}}
                            {{i18n "guest_cta.admin.leading"}}</span>
                        {{/if}}
                      </td>
                      <td class="guest-cta-overview__num">{{v.impressions}}</td>
                      <td class="guest-cta-overview__num">{{v.clicks}}</td>
                      <td class="guest-cta-overview__num"><strong
                        >{{v.ctr}}</strong></td>
                      <td class="guest-cta-overview__num">
                        {{#if v.isControl}}
                          <span class="guest-cta-muted">–</span>
                        {{else if v.lift}}
                          {{v.lift}}
                          <span
                            class="guest-cta-muted
                              {{if v.significant 'guest-cta-overview__sig'}}"
                            title={{i18n "guest_cta.admin.confidence_help"}}
                          >
                            ({{v.confidence}}{{#if v.significant}}
                              {{icon "check"}}{{/if}})
                          </span>
                        {{else}}
                          <span class="guest-cta-muted">{{i18n
                              "guest_cta.admin.not_enough_data"
                            }}</span>
                        {{/if}}
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            {{else if row.baseline}}
              <p class="guest-cta-muted guest-cta-overview__current">
                {{#if row.test}}
                  {{i18n "guest_cta.admin.overview.current_while_draft"}}
                {{else}}
                  {{i18n "guest_cta.admin.overview.no_test"}}
                {{/if}}
              </p>
              <StatTiles
                @stats={{row.baseline.stats}}
                class="guest-cta-tiles--compact"
              />
            {{/if}}
          </div>
        {{/each}}
      </div>
    </section>
  </template>
}
