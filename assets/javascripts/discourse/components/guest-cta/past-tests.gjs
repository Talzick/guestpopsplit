import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { formatDate, formatNumber } from "../../lib/guest-cta/format";
import ResultsTable from "./results-table";

// Collapsible history of ended tests with their previews and final numbers.
export default class PastTests extends Component {
  @tracked openIds = new Set();

  get rows() {
    return (this.args.tests || []).map((test) => {
      const winner = (test.variants || []).find(
        (v) => v.id === test.winner_variant_id
      );
      return {
        test,
        open: this.openIds.has(test.id),
        started: formatDate(test.started_at),
        ended: formatDate(test.ended_at),
        impressions: formatNumber(test.total_impressions),
        clicks: formatNumber(test.total_clicks),
        winnerName: winner ? winner.name : null,
        variantCount: (test.variants || []).length,
      };
    });
  }

  @action
  toggle(id) {
    const next = new Set(this.openIds);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    this.openIds = next;
  }

  <template>
    {{#if this.rows.length}}
      <div class="guest-cta-history">
        {{#each this.rows as |row|}}
          <div
            class="guest-cta-history__item
              {{if row.open 'guest-cta-history__item--open'}}"
          >
            <button
              type="button"
              class="guest-cta-history__summary"
              {{on "click" (fn this.toggle row.test.id)}}
            >
              <span class="guest-cta-history__name">{{row.test.name}}</span>
              <span class="guest-cta-history__dates">{{row.started}}
                –
                {{row.ended}}</span>
              <span class="guest-cta-history__counts">
                {{i18n
                  "guest_cta.admin.history_counts"
                  variants=row.variantCount
                  impressions=row.impressions
                  clicks=row.clicks
                }}
              </span>
              <span class="guest-cta-history__winner">
                {{#if row.winnerName}}
                  {{i18n "guest_cta.admin.history_winner" name=row.winnerName}}
                {{else}}
                  {{i18n "guest_cta.admin.history_no_winner"}}
                {{/if}}
              </span>
              <span class="guest-cta-history__chevron">{{icon
                  (if row.open "chevron-up" "chevron-down")
                }}</span>
            </button>
            {{#if row.open}}
              <div class="guest-cta-history__body">
                <ResultsTable @test={{row.test}} @mode="ended" @compact={{true}} />
              </div>
            {{/if}}
          </div>
        {{/each}}
      </div>
    {{else}}
      <p class="guest-cta-muted">{{i18n "guest_cta.admin.no_past_tests"}}</p>
    {{/if}}
  </template>
}
