import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  formatNumber,
  formatPercent,
  formatSignedPercent,
} from "../../lib/guest-cta/format";
import VariantPreview from "./variant-preview";

// "Shows after 3s" / "Shows instantly", popup only. Lets admins tell variants
// apart when the delay is the only thing that differs.
function delayNote(placement, variant) {
  if (placement === "banner") {
    return null;
  }
  const seconds = Number(variant.show_delay_seconds) || 0;
  return seconds > 0
    ? i18n("guest_cta.admin.shows_after", { seconds })
    : i18n("guest_cta.admin.shows_instantly");
}

// One row per variant: preview, counts, CTR, and how it compares to control.
// @mode is "draft", "running" or "ended".
export default class ResultsTable extends Component {
  get rows() {
    const test = this.args.test;
    return (test.variants || []).map((variant) => {
      const sig = variant.significance;
      return {
        variant,
        impressions: formatNumber(variant.stats?.impressions),
        clicks: formatNumber(variant.stats?.clicks),
        ctr: formatPercent(variant.stats?.ctr),
        lift: sig ? formatSignedPercent(sig.lift) : null,
        confidence: sig ? `${sig.confidence}%` : null,
        significant: !!sig?.significant,
        isLeader: !!variant.is_leader,
        isWinner: test.winner_variant_id === variant.id,
        isControl: variant.is_control,
        delayNote: delayNote(test.placement, variant),
      };
    });
  }

  get showStats() {
    return this.args.mode !== "draft";
  }

  <template>
    <table class="guest-cta-results {{if @compact 'guest-cta-results--compact'}}">
      <thead>
        <tr>
          <th class="guest-cta-results__variant">{{i18n
              "guest_cta.admin.variant"
            }}</th>
          {{#if this.showStats}}
            <th class="guest-cta-results__num">{{i18n
                "guest_cta.admin.impressions"
              }}</th>
            <th class="guest-cta-results__num">{{i18n
                "guest_cta.admin.clicks"
              }}</th>
            <th class="guest-cta-results__num">{{i18n "guest_cta.admin.ctr"}}</th>
            <th class="guest-cta-results__num">{{i18n
                "guest_cta.admin.vs_control"
              }}</th>
          {{/if}}
          {{#unless (eq @mode "ended")}}
            <th class="guest-cta-results__actions"></th>
          {{/unless}}
        </tr>
      </thead>
      <tbody>
        {{#each this.rows as |row|}}
          <tr
            class="guest-cta-results__row
              {{if row.isLeader 'guest-cta-results__row--leader'}}
              {{if row.isWinner 'guest-cta-results__row--winner'}}"
          >
            <td class="guest-cta-results__variant">
              <div class="guest-cta-results__variant-inner">
                <VariantPreview
                  @variant={{row.variant}}
                  @placement={{@test.placement}}
                  @small={{true}}
                />
                <div class="guest-cta-results__meta">
                  <span class="guest-cta-results__name">{{row.variant.name}}</span>
                  <span class="guest-cta-results__badges">
                    {{#if row.isControl}}
                      <span class="guest-cta-badge guest-cta-badge--control">{{i18n
                          "guest_cta.admin.control"
                        }}</span>
                    {{/if}}
                    {{#if row.isWinner}}
                      <span class="guest-cta-badge guest-cta-badge--winner">{{icon
                          "trophy"
                        }}
                        {{i18n "guest_cta.admin.winner"}}</span>
                    {{else if row.isLeader}}
                      {{#if this.showStats}}
                        <span class="guest-cta-badge guest-cta-badge--leader">{{icon
                            "trophy"
                          }}
                          {{i18n "guest_cta.admin.leading"}}</span>
                      {{/if}}
                    {{/if}}
                  </span>
                  <span class="guest-cta-results__heading-text">{{row.variant.heading}}</span>
                  {{#if row.delayNote}}
                    <span class="guest-cta-results__delay">{{row.delayNote}}</span>
                  {{/if}}
                </div>
              </div>
            </td>
            {{#if this.showStats}}
              <td class="guest-cta-results__num">{{row.impressions}}</td>
              <td class="guest-cta-results__num">{{row.clicks}}</td>
              <td class="guest-cta-results__num guest-cta-results__ctr">{{row.ctr}}</td>
              <td class="guest-cta-results__num">
                {{#if row.isControl}}
                  <span class="guest-cta-muted">–</span>
                {{else if row.lift}}
                  <span class="guest-cta-results__lift">{{row.lift}}</span>
                  <span
                    class="guest-cta-results__confidence
                      {{if row.significant 'guest-cta-results__confidence--sig'}}"
                    title={{i18n "guest_cta.admin.confidence_help"}}
                  >
                    {{i18n "guest_cta.admin.confidence" value=row.confidence}}
                    {{#if row.significant}}{{icon "check"}}{{/if}}
                  </span>
                {{else}}
                  <span class="guest-cta-muted">{{i18n
                      "guest_cta.admin.not_enough_data"
                    }}</span>
                {{/if}}
              </td>
            {{/if}}
            {{#unless (eq @mode "ended")}}
              <td class="guest-cta-results__actions">
                {{#if (eq @mode "running")}}
                  <DButton
                    @action={{fn @onPickWinner row.variant}}
                    @icon="trophy"
                    @label="guest_cta.admin.make_default"
                    class="btn-primary btn-small"
                  />
                {{/if}}
                {{#if @onEdit}}
                  <DButton
                    @action={{fn @onEdit row.variant}}
                    @icon="pencil"
                    @title="guest_cta.admin.edit"
                    class="btn-flat btn-small"
                  />
                {{/if}}
                {{#if @onDelete}}
                  {{#unless row.isControl}}
                    <DButton
                      @action={{fn @onDelete row.variant}}
                      @icon="trash-can"
                      @title="guest_cta.admin.delete"
                      class="btn-flat btn-small btn-danger"
                    />
                  {{/unless}}
                {{/if}}
              </td>
            {{/unless}}
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
}
