import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { formatDate } from "../../lib/guest-cta/format";
import {
  placementEnabled,
  setPlacementEnabled,
} from "../../lib/guest-cta/settings";
import PastTests from "./past-tests";
import ResultsTable from "./results-table";
import StatTiles from "./stat-tiles";
import VariantFormModal from "./variant-form-modal";
import VariantPreview from "./variant-preview";

const VARIANT_LETTERS = "BCDEFGHIJKLMNOPQRSTUVWXYZ";

// One dashboard per placement ("popup", "banner" or "reply"): current version with
// its numbers, the draft/running test, and the history of past tests.
export default class GuestCtaDashboard extends Component {
  @service modal;
  @service dialog;
  @service siteSettings;

  @tracked data = this.args.model;
  @tracked newTestName = "";
  @tracked busy = false;
  @tracked togglingVisibility = false;

  get placement() {
    return this.args.placement || this.data.placement || "popup";
  }

  get isBanner() {
    return this.placement === "banner";
  }

  get isReply() {
    return this.placement === "reply";
  }

  get isPopup() {
    return !this.isBanner && !this.isReply;
  }

  // Placement-specific wording lives under guest_cta.admin.<placement>.*
  t(key, params) {
    return i18n(`guest_cta.admin.${this.placement}.${key}`, params);
  }

  get baseline() {
    return this.data.baseline;
  }

  get test() {
    return this.data.current_test;
  }

  get testIsDraft() {
    return this.test?.status === "draft";
  }

  get testIsRunning() {
    return this.test?.status === "running";
  }

  get testStarted() {
    return formatDate(this.test?.started_at);
  }

  get canCreateTest() {
    return this.newTestName.trim().length > 0;
  }

  get canStart() {
    return this.testIsDraft && (this.test.variants || []).length >= 2;
  }

  // Popup only: how long after page load the current version appears.
  get baselineDelayNote() {
    if (!this.isPopup) {
      return null;
    }
    const seconds = Number(this.baseline.show_delay_seconds) || 0;
    return seconds > 0
      ? i18n("guest_cta.admin.shows_after", { seconds })
      : i18n("guest_cta.admin.shows_instantly");
  }

  get baselineStatsNote() {
    if (this.baseline.stats_from) {
      return i18n("guest_cta.admin.baseline_stats_since", {
        date: formatDate(this.baseline.stats_from),
      });
    }
    return i18n("guest_cta.admin.baseline_stats_all_time");
  }

  get placementEnabled() {
    return placementEnabled(this.siteSettings, this.placement);
  }

  get placementDisabled() {
    return !this.placementEnabled;
  }

  get visibilityLabel() {
    return this.t("visibility_label");
  }

  get heading() {
    return this.t("heading");
  }

  get description() {
    return this.t("description");
  }

  get baselineHeading() {
    return this.t("baseline_heading");
  }

  get baselineDescription() {
    return this.testIsRunning
      ? this.t("baseline_paused")
      : this.t("baseline_description");
  }

  get disabledWarning() {
    return this.t("disabled_warning");
  }

  // Banner and reply start empty and show nothing until they are set up.
  get notConfigured() {
    if (this.isBanner) {
      return !this.baseline.image_url;
    }
    if (this.isReply) {
      return !this.baseline.reply_raw || !this.baseline.reply_name;
    }
    return false;
  }

  get notConfiguredNote() {
    return this.t("not_configured");
  }

  get newTestDescription() {
    return this.t("new_test_description");
  }

  get nextVariantName() {
    const count = (this.test?.variants || []).length;
    const letter = VARIANT_LETTERS[Math.max(0, count - 1)] || `${count + 1}`;
    return i18n("guest_cta.admin.default_variant_name", { letter });
  }

  @action
  async reload() {
    this.busy = true;
    try {
      this.data = await ajax("/guest-cta/admin/dashboard.json", {
        data: { placement: this.placement },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  async request(url, type, data) {
    this.busy = true;
    try {
      await ajax(url, { type, data: { placement: this.placement, ...data } });
      await this.reload();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  @action
  async toggleVisibility() {
    this.togglingVisibility = true;
    try {
      await setPlacementEnabled(
        this.siteSettings,
        this.placement,
        !this.placementEnabled,
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.togglingVisibility = false;
    }
  }

  @action
  editBaseline() {
    this.modal.show(VariantFormModal, {
      model: {
        variant: this.baseline,
        placement: this.placement,
        url: "/guest-cta/admin/baseline",
        method: "PUT",
        isBaseline: true,
        title: this.t("edit_baseline_title"),
        onSaved: this.reload,
      },
    });
  }

  @action
  updateNewTestName(event) {
    this.newTestName = event.target.value;
  }

  @action
  createTest() {
    const name = this.newTestName.trim();
    if (!name) {
      return;
    }
    this.newTestName = "";
    return this.request("/guest-cta/admin/tests", "POST", { name });
  }

  @action
  addVariant() {
    const control =
      (this.test.variants || []).find((v) => v.is_control) || this.baseline;
    this.modal.show(VariantFormModal, {
      model: {
        variant: { ...control, name: this.nextVariantName },
        placement: this.placement,
        url: "/guest-cta/admin/variants",
        method: "POST",
        testId: this.test.id,
        title: i18n("guest_cta.admin.add_variant_title"),
        onSaved: this.reload,
      },
    });
  }

  @action
  editVariant(variant) {
    this.modal.show(VariantFormModal, {
      model: {
        variant,
        placement: this.placement,
        url: `/guest-cta/admin/variants/${variant.id}`,
        method: "PUT",
        title: i18n("guest_cta.admin.edit_variant_title", {
          name: variant.name,
        }),
        onSaved: this.reload,
      },
    });
  }

  @action
  deleteVariant(variant) {
    this.dialog.deleteConfirm({
      message: i18n("guest_cta.admin.confirm_delete_variant", {
        name: variant.name,
      }),
      didConfirm: () =>
        this.request(`/guest-cta/admin/variants/${variant.id}`, "DELETE"),
    });
  }

  @action
  startTest() {
    this.dialog.yesNoConfirm({
      message: i18n("guest_cta.admin.confirm_start", { name: this.test.name }),
      didConfirm: () =>
        this.request(`/guest-cta/admin/tests/${this.test.id}/start`, "PUT"),
    });
  }

  @action
  deleteTest() {
    this.dialog.deleteConfirm({
      message: i18n("guest_cta.admin.confirm_delete_test", {
        name: this.test.name,
      }),
      didConfirm: () =>
        this.request(`/guest-cta/admin/tests/${this.test.id}`, "DELETE"),
    });
  }

  @action
  pickWinner(variant) {
    const key = variant.is_control
      ? "guest_cta.admin.confirm_winner_control"
      : "guest_cta.admin.confirm_winner";
    this.dialog.yesNoConfirm({
      message: i18n(key, { name: variant.name }),
      didConfirm: () =>
        this.request(`/guest-cta/admin/tests/${this.test.id}/finish`, "PUT", {
          winner_variant_id: variant.id,
        }),
    });
  }

  @action
  endWithoutWinner() {
    this.dialog.yesNoConfirm({
      message: i18n("guest_cta.admin.confirm_end_no_winner"),
      didConfirm: () =>
        this.request(`/guest-cta/admin/tests/${this.test.id}/finish`, "PUT"),
    });
  }

  <template>
    <div class="guest-cta-admin guest-cta-admin--{{this.placement}}">
      <div class="guest-cta-switcher">
        <LinkTo
          @route="adminPlugins.show.guest-cta-ab-dashboard"
          class="guest-cta-switcher__link
            {{if
              (eq this.placement 'popup')
              'guest-cta-switcher__link--active'
            }}"
        >
          {{i18n "guest_cta.admin.nav_popup"}}
        </LinkTo>
        <LinkTo
          @route="adminPlugins.show.guest-cta-ab-banner"
          class="guest-cta-switcher__link
            {{if
              (eq this.placement 'banner')
              'guest-cta-switcher__link--active'
            }}"
        >
          {{i18n "guest_cta.admin.nav_banner"}}
        </LinkTo>
        <LinkTo
          @route="adminPlugins.show.guest-cta-ab-reply"
          class="guest-cta-switcher__link
            {{if
              (eq this.placement 'reply')
              'guest-cta-switcher__link--active'
            }}"
        >
          {{i18n "guest_cta.admin.nav_reply"}}
        </LinkTo>
      </div>

      <div class="guest-cta-admin__header">
        <div>
          <h2>{{this.heading}}</h2>
          <p class="guest-cta-muted">{{this.description}}</p>
        </div>
        <DButton
          @action={{this.reload}}
          @icon="rotate"
          @label="guest_cta.admin.refresh"
          @isLoading={{this.busy}}
          class="btn-default"
        />
      </div>

      <div class="guest-cta-admin__visibility">
        <DToggleSwitch
          @state={{this.placementEnabled}}
          @translatedLabel={{this.visibilityLabel}}
          disabled={{this.togglingVisibility}}
          {{on "click" this.toggleVisibility}}
        />
      </div>
      {{#if this.placementDisabled}}
        <div class="alert alert-warning">{{this.disabledWarning}}</div>
      {{/if}}
      {{#if this.notConfigured}}
        <div class="alert alert-info">{{this.notConfiguredNote}}</div>
      {{/if}}

      <section class="guest-cta-card guest-cta-baseline">
        <div class="guest-cta-card__header">
          <h3>{{this.baselineHeading}}</h3>
          <DButton
            @action={{this.editBaseline}}
            @icon="pencil"
            @label="guest_cta.admin.edit_baseline"
            class="btn-default"
          />
        </div>
        <p class="guest-cta-muted">{{this.baselineDescription}}</p>
        <div class="guest-cta-baseline__layout">
          <VariantPreview
            @variant={{this.baseline}}
            @placement={{this.placement}}
          />
          <div class="guest-cta-baseline__stats">
            <StatTiles @stats={{this.baseline.stats}} />
            {{#if this.baselineDelayNote}}
              <small class="guest-cta-muted guest-cta-baseline__delay">{{this.baselineDelayNote}}</small>
            {{/if}}
            <small class="guest-cta-muted">{{this.baselineStatsNote}}</small>
          </div>
        </div>
      </section>

      <section class="guest-cta-card guest-cta-test">
        {{#if this.test}}
          <div class="guest-cta-card__header">
            <h3>
              {{this.test.name}}
              <span
                class="guest-cta-badge guest-cta-badge--{{this.test.status}}"
              >
                {{#if this.testIsRunning}}
                  {{i18n "guest_cta.admin.status_running"}}
                {{else}}
                  {{i18n "guest_cta.admin.status_draft"}}
                {{/if}}
              </span>
            </h3>
            <div class="guest-cta-card__actions">
              {{#if this.testIsDraft}}
                <DButton
                  @action={{this.addVariant}}
                  @icon="plus"
                  @label="guest_cta.admin.add_variant"
                  class="btn-default"
                />
                <DButton
                  @action={{this.startTest}}
                  @icon="play"
                  @label="guest_cta.admin.start_test"
                  @disabled={{not this.canStart}}
                  class="btn-primary"
                />
                <DButton
                  @action={{this.deleteTest}}
                  @icon="trash-can"
                  @label="guest_cta.admin.delete_test"
                  class="btn-danger btn-flat"
                />
              {{else}}
                <DButton
                  @action={{this.endWithoutWinner}}
                  @icon="stop"
                  @label="guest_cta.admin.end_without_winner"
                  class="btn-default"
                />
              {{/if}}
            </div>
          </div>

          {{#if this.testIsDraft}}
            <p class="guest-cta-muted">{{i18n
                "guest_cta.admin.draft_description"
              }}</p>
          {{else}}
            <p class="guest-cta-muted">{{i18n
                "guest_cta.admin.running_description"
                date=this.testStarted
              }}</p>
          {{/if}}

          <ResultsTable
            @test={{this.test}}
            @mode={{this.test.status}}
            @onEdit={{this.editVariant}}
            @onDelete={{if this.testIsDraft this.deleteVariant}}
            @onPickWinner={{this.pickWinner}}
          />
        {{else}}
          <div class="guest-cta-card__header">
            <h3>{{i18n "guest_cta.admin.new_test_heading"}}</h3>
          </div>
          <p class="guest-cta-muted">{{this.newTestDescription}}</p>
          <div class="guest-cta-new-test">
            <input
              type="text"
              value={{this.newTestName}}
              placeholder={{i18n "guest_cta.admin.new_test_placeholder"}}
              {{on "input" this.updateNewTestName}}
            />
            <DButton
              @action={{this.createTest}}
              @icon="flask"
              @label="guest_cta.admin.create_test"
              @disabled={{not this.canCreateTest}}
              class="btn-primary"
            />
          </div>
        {{/if}}
      </section>

      <section class="guest-cta-card guest-cta-past">
        <div class="guest-cta-card__header">
          <h3>{{i18n "guest_cta.admin.past_tests_heading"}}</h3>
        </div>
        <PastTests @tests={{this.data.past_tests}} />
      </section>
    </div>
  </template>
}
