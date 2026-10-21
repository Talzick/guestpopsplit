import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { cook } from "discourse/lib/text";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import CategorySelector from "select-kit/components/category-selector";
import { applyOverride } from "../../lib/guest-cta/ad-reply-markup";
import VariantPreview from "./variant-preview";

const POPUP_FIELDS = [
  "heading",
  "image_url",
  "image_max_width_px",
  "subheading",
  "body_text",
  "button_text",
  "button_url",
  "button_color",
  "button_text_color",
  "button_glow",
  "open_in_new_tab",
  "show_delay_seconds",
];

const BANNER_FIELDS = [
  "image_url",
  "mobile_image_url",
  "alt_text",
  "button_url",
  "open_in_new_tab",
];

// The reply's cooked HTML is derived on the server, so it is not a form field.
const REPLY_FIELDS = [
  "reply_name",
  "reply_avatar_url",
  "reply_raw",
  "reply_like_count",
  "button_text",
  "button_url",
  "open_in_new_tab",
];

const DEFAULT_MESSAGE_KEY = "default";

function emptyOverride() {
  return { category_ids: [], reply_raw: "", button_text: "", button_url: "" };
}

const PREVIEW_DEBOUNCE_MS = 350;

// Edit form for the baseline or a test variant, with a live preview.
//
// @model: { variant, placement, url, method, testId, isBaseline, title, onSaved }
export default class VariantFormModal extends Component {
  @service site;

  @tracked form;
  @tracked saving = false;
  @tracked flash = null;

  // Reply only: the preview needs each message cooked, which happens a moment
  // after the admin stops typing. Keyed by "default" or the override's index.
  @tracked previewCooked = {};
  @tracked previewKey = DEFAULT_MESSAGE_KEY;
  #cookTimers = {};

  constructor() {
    super(...arguments);
    const source = this.args.model.variant || {};
    const form = { name: source.name || "" };
    this.fields.forEach((field) => {
      form[field] = source[field] ?? "";
    });
    form.open_in_new_tab = !!source.open_in_new_tab;
    if (this.isPopup) {
      form.button_glow = !!source.button_glow;
      form.image_max_width_px = source.image_max_width_px || 220;
      form.show_delay_seconds = source.show_delay_seconds ?? 0;
    }
    if (this.isReply) {
      form.reply_like_count = source.reply_like_count ?? 0;
      form.reply_category_overrides = (source.reply_category_overrides || []).map(
        (o) => ({
          category_ids: (o.category_ids || []).map(Number),
          reply_raw: o.reply_raw || "",
          button_text: o.button_text || "",
          button_url: o.button_url || "",
        })
      );
    }
    this.form = form;

    if (this.isReply) {
      const cooked = { [DEFAULT_MESSAGE_KEY]: source.reply_cooked || "" };
      (source.reply_category_overrides || []).forEach((o, i) => {
        cooked[i] = o.reply_cooked || "";
      });
      this.previewCooked = cooked;
      if (!cooked[DEFAULT_MESSAGE_KEY] && form.reply_raw) {
        this.recook(DEFAULT_MESSAGE_KEY);
      }
      form.reply_category_overrides.forEach((o, i) => {
        if (!cooked[i] && o.reply_raw) {
          this.recook(i);
        }
      });
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    Object.values(this.#cookTimers).forEach((t) => clearTimeout(t));
  }

  get placement() {
    return this.args.model.placement || "popup";
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

  get fields() {
    if (this.isBanner) {
      return BANNER_FIELDS;
    }
    if (this.isReply) {
      return REPLY_FIELDS;
    }
    return POPUP_FIELDS;
  }

  // What the preview shows. For the reply that is the form plus the cooked
  // default message, which the server will produce on save.
  get previewVariant() {
    if (!this.isReply) {
      return this.form;
    }
    return { ...this.form, reply_cooked: this.previewCooked[DEFAULT_MESSAGE_KEY] || "" };
  }

  // Reply only: the message the preview shows, default or a chosen override.
  get previewMessage() {
    const base = {
      reply_cooked: this.previewCooked[DEFAULT_MESSAGE_KEY] || "",
      button_text: this.form.button_text || "",
      button_url: this.form.button_url || "",
    };
    if (this.previewKey === DEFAULT_MESSAGE_KEY) {
      return base;
    }
    const override = this.overrides[Number(this.previewKey)];
    if (!override) {
      return base;
    }
    return applyOverride(base, {
      ...override,
      reply_cooked: this.previewCooked[this.previewKey] || "",
    });
  }

  get overrides() {
    return this.form.reply_category_overrides || [];
  }

  // Overrides with the data the template needs: the Category objects for the
  // selector and a label for the preview picker.
  get overrideRows() {
    return this.overrides.map((override, index) => {
      const categories = Category.findByIds(override.category_ids || []);
      return {
        index,
        key: String(index),
        override,
        categories,
        label:
          categories.length > 0
            ? categories.map((c) => c.name).join(", ")
            : i18n("guest_cta.admin.fields.reply_override_untitled", {
                number: index + 1,
              }),
      };
    });
  }

  get showPreviewPicker() {
    return this.isReply && this.overrides.length > 0;
  }

  rawFor(key) {
    return key === DEFAULT_MESSAGE_KEY
      ? this.form.reply_raw || ""
      : this.overrides[Number(key)]?.reply_raw || "";
  }

  scheduleRecook(key) {
    clearTimeout(this.#cookTimers[key]);
    this.#cookTimers[key] = setTimeout(() => this.recook(key), PREVIEW_DEBOUNCE_MS);
  }

  async recook(key) {
    const raw = this.rawFor(key);
    if (!raw.trim()) {
      this.previewCooked = { ...this.previewCooked, [key]: "" };
      return;
    }
    try {
      const cooked = await cook(raw);
      if (!this.isDestroying && this.rawFor(key) === raw) {
        this.previewCooked = { ...this.previewCooked, [key]: cooked.toString() };
      }
    } catch {
      // The preview is best-effort; the server cooks the real thing on save.
    }
  }

  // Re-keys the cooked previews after an override is removed.
  reindexPreviews(overrides) {
    const cooked = { [DEFAULT_MESSAGE_KEY]: this.previewCooked[DEFAULT_MESSAGE_KEY] || "" };
    overrides.forEach((o, i) => {
      cooked[i] = o._cooked ?? "";
    });
    this.previewCooked = cooked;
  }

  @action
  update(field, event) {
    this.form = { ...this.form, [field]: event.target.value };
    if (field === "reply_raw") {
      this.scheduleRecook(DEFAULT_MESSAGE_KEY);
    }
  }

  @action
  setPreviewKey(event) {
    this.previewKey = event.target.value;
  }

  @action
  addOverride() {
    const overrides = [...this.overrides, emptyOverride()];
    this.form = { ...this.form, reply_category_overrides: overrides };
    this.previewKey = String(overrides.length - 1);
  }

  @action
  removeOverride(index) {
    const kept = this.overrides
      .map((o, i) => ({ ...o, _cooked: this.previewCooked[i] || "" }))
      .filter((_, i) => i !== index);
    this.reindexPreviews(kept);
    this.form = {
      ...this.form,
      reply_category_overrides: kept.map(({ _cooked, ...o }) => o),
    };
    this.previewKey = DEFAULT_MESSAGE_KEY;
  }

  @action
  updateOverride(index, field, event) {
    const overrides = this.overrides.map((o, i) =>
      i === index ? { ...o, [field]: event.target.value } : o
    );
    this.form = { ...this.form, reply_category_overrides: overrides };
    if (field === "reply_raw") {
      this.scheduleRecook(String(index));
    }
  }

  @action
  updateOverrideCategories(index, categories) {
    const ids = (categories || []).map((c) => c.id);
    const overrides = this.overrides.map((o, i) =>
      i === index ? { ...o, category_ids: ids } : o
    );
    this.form = { ...this.form, reply_category_overrides: overrides };
  }

  // Reply only: an uploaded image is appended to the message as Markdown, the
  // same way the composer would insert it.
  @action
  insertImage(upload) {
    const alt = (upload.original_filename || "image").replace(/\.[^.]+$/, "");
    const markdown = `![${alt}](${upload.url})`;
    const raw = this.form.reply_raw || "";
    const joined = raw.trim() ? `${raw.replace(/\s+$/, "")}\n\n${markdown}\n` : `${markdown}\n`;
    this.form = { ...this.form, reply_raw: joined };
    this.scheduleRecook(DEFAULT_MESSAGE_KEY);
  }

  @action
  updateBool(field, event) {
    this.form = { ...this.form, [field]: event.target.checked };
  }

  @action
  uploadDone(field, upload) {
    this.form = { ...this.form, [field]: upload.url };
  }

  @action
  uploadDeleted(field) {
    this.form = { ...this.form, [field]: "" };
  }

  @action
  async save() {
    this.saving = true;
    this.flash = null;
    const variant = { ...this.form };
    if (this.isReply) {
      // Sent as one JSON string so an emptied list still reaches the server.
      variant.reply_category_overrides = JSON.stringify(this.overrides);
    }
    const data = { variant, placement: this.placement };
    if (this.args.model.testId) {
      data.test_id = this.args.model.testId;
    }
    try {
      await ajax(this.args.model.url, { type: this.args.model.method, data });
      await this.args.model.onSaved?.();
      this.args.closeModal();
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @title={{this.title}}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      class="guest-cta-variant-modal guest-cta-variant-modal--{{this.placement}}"
    >
      <:body>
        <div class="guest-cta-variant-modal__layout">
          <div class="guest-cta-variant-modal__form">
            {{#unless this.isBaseline}}
              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.name"}}</span>
                <input
                  type="text"
                  value={{this.form.name}}
                  placeholder={{i18n "guest_cta.admin.fields.name_placeholder"}}
                  {{on "input" (fn this.update "name")}}
                />
                <small>{{i18n "guest_cta.admin.fields.name_help"}}</small>
              </label>
            {{/unless}}

            {{#if this.isBanner}}
              {{! ---------- Banner fields ---------- }}
              <div class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.banner_image"}}</span>
                <UppyImageUploader
                  @id="guest-cta-banner-image"
                  @type="composer"
                  @imageUrl={{this.form.image_url}}
                  @onUploadDone={{fn this.uploadDone "image_url"}}
                  @onUploadDeleted={{fn this.uploadDeleted "image_url"}}
                />
                <input
                  type="text"
                  class="guest-cta-field__url"
                  value={{this.form.image_url}}
                  placeholder={{i18n "guest_cta.admin.fields.image_url_placeholder"}}
                  {{on "input" (fn this.update "image_url")}}
                />
                <small>{{i18n "guest_cta.admin.fields.banner_image_help"}}</small>
              </div>

              <div class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.banner_mobile_image"}}</span>
                <UppyImageUploader
                  @id="guest-cta-banner-mobile-image"
                  @type="composer"
                  @imageUrl={{this.form.mobile_image_url}}
                  @onUploadDone={{fn this.uploadDone "mobile_image_url"}}
                  @onUploadDeleted={{fn this.uploadDeleted "mobile_image_url"}}
                />
                <input
                  type="text"
                  class="guest-cta-field__url"
                  value={{this.form.mobile_image_url}}
                  placeholder={{i18n "guest_cta.admin.fields.image_url_placeholder"}}
                  {{on "input" (fn this.update "mobile_image_url")}}
                />
                <small>{{i18n "guest_cta.admin.fields.banner_mobile_image_help"}}</small>
              </div>

              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.alt_text"}}</span>
                <input
                  type="text"
                  value={{this.form.alt_text}}
                  {{on "input" (fn this.update "alt_text")}}
                />
                <small>{{i18n "guest_cta.admin.fields.alt_text_help"}}</small>
              </label>

              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.banner_link"}}</span>
                <input
                  type="text"
                  value={{this.form.button_url}}
                  {{on "input" (fn this.update "button_url")}}
                />
              </label>
            {{else if this.isReply}}
              {{! ---------- Reply fields ---------- }}
              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.reply_name"}}</span>
                <input
                  type="text"
                  value={{this.form.reply_name}}
                  placeholder={{i18n
                    "guest_cta.admin.fields.reply_name_placeholder"
                  }}
                  {{on "input" (fn this.update "reply_name")}}
                />
                <small>{{i18n "guest_cta.admin.fields.reply_name_help"}}</small>
              </label>

              <div class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.reply_avatar"}}</span>
                <UppyImageUploader
                  @id="guest-cta-reply-avatar"
                  @type="composer"
                  @imageUrl={{this.form.reply_avatar_url}}
                  @onUploadDone={{fn this.uploadDone "reply_avatar_url"}}
                  @onUploadDeleted={{fn this.uploadDeleted "reply_avatar_url"}}
                />
                <input
                  type="text"
                  class="guest-cta-field__url"
                  value={{this.form.reply_avatar_url}}
                  placeholder={{i18n "guest_cta.admin.fields.image_url_placeholder"}}
                  {{on "input" (fn this.update "reply_avatar_url")}}
                />
                <small>{{i18n "guest_cta.admin.fields.reply_avatar_help"}}</small>
              </div>

              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.reply_message"}}</span>
                <textarea
                  rows="10"
                  class="guest-cta-field__markdown"
                  value={{this.form.reply_raw}}
                  placeholder={{i18n
                    "guest_cta.admin.fields.reply_message_placeholder"
                  }}
                  {{on "input" (fn this.update "reply_raw")}}
                ></textarea>
                <small>{{i18n "guest_cta.admin.fields.reply_message_help"}}</small>
              </label>

              <div class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.reply_insert_image"}}</span>
                <UppyImageUploader
                  @id="guest-cta-reply-image"
                  @type="composer"
                  @onUploadDone={{this.insertImage}}
                />
                <small>{{i18n "guest_cta.admin.fields.reply_insert_image_help"}}</small>
              </div>

              <div class="guest-cta-field-row">
                <label class="guest-cta-field">
                  <span>{{i18n "guest_cta.admin.fields.reply_button_text"}}</span>
                  <input
                    type="text"
                    value={{this.form.button_text}}
                    placeholder={{i18n
                      "guest_cta.admin.fields.reply_button_text_placeholder"
                    }}
                    {{on "input" (fn this.update "button_text")}}
                  />
                </label>
                <label class="guest-cta-field">
                  <span>{{i18n "guest_cta.admin.fields.reply_button_url"}}</span>
                  <input
                    type="text"
                    value={{this.form.button_url}}
                    {{on "input" (fn this.update "button_url")}}
                  />
                </label>
              </div>
              <small class="guest-cta-field__note">{{i18n
                  "guest_cta.admin.fields.reply_button_help"
                }}</small>

              <label class="guest-cta-field guest-cta-field--short">
                <span>{{i18n "guest_cta.admin.fields.reply_like_count"}}</span>
                <input
                  type="number"
                  min="0"
                  max="1000000"
                  step="1"
                  value={{this.form.reply_like_count}}
                  {{on "input" (fn this.update "reply_like_count")}}
                />
                <small>{{i18n "guest_cta.admin.fields.reply_like_count_help"}}</small>
              </label>

              <div class="guest-cta-overrides">
                <div class="guest-cta-overrides__header">
                  <span class="guest-cta-overrides__title">{{i18n
                      "guest_cta.admin.fields.reply_overrides"
                    }}</span>
                  <DButton
                    @action={{this.addOverride}}
                    @icon="plus"
                    @label="guest_cta.admin.fields.reply_add_override"
                    class="btn-default btn-small"
                  />
                </div>
                <small>{{i18n "guest_cta.admin.fields.reply_overrides_help"}}</small>

                {{#each this.overrideRows as |row|}}
                  <div class="guest-cta-override">
                    <div class="guest-cta-override__header">
                      <span class="guest-cta-override__label">{{row.label}}</span>
                      <DButton
                        @action={{fn this.removeOverride row.index}}
                        @icon="trash-can"
                        @title="guest_cta.admin.fields.reply_remove_override"
                        class="btn-flat btn-small btn-danger"
                      />
                    </div>

                    <div class="guest-cta-field">
                      <span>{{i18n "guest_cta.admin.fields.reply_override_categories"}}</span>
                      <CategorySelector
                        @categories={{row.categories}}
                        @onChange={{fn this.updateOverrideCategories row.index}}
                      />
                      <small>{{i18n
                          "guest_cta.admin.fields.reply_override_categories_help"
                        }}</small>
                    </div>

                    <label class="guest-cta-field">
                      <span>{{i18n "guest_cta.admin.fields.reply_override_message"}}</span>
                      <textarea
                        rows="6"
                        class="guest-cta-field__markdown"
                        value={{row.override.reply_raw}}
                        placeholder={{i18n
                          "guest_cta.admin.fields.reply_override_message_placeholder"
                        }}
                        {{on "input" (fn this.updateOverride row.index "reply_raw")}}
                      ></textarea>
                    </label>

                    <div class="guest-cta-field-row">
                      <label class="guest-cta-field">
                        <span>{{i18n "guest_cta.admin.fields.reply_button_text"}}</span>
                        <input
                          type="text"
                          value={{row.override.button_text}}
                          placeholder={{i18n
                            "guest_cta.admin.fields.reply_override_inherit"
                          }}
                          {{on
                            "input"
                            (fn this.updateOverride row.index "button_text")
                          }}
                        />
                      </label>
                      <label class="guest-cta-field">
                        <span>{{i18n "guest_cta.admin.fields.reply_button_url"}}</span>
                        <input
                          type="text"
                          value={{row.override.button_url}}
                          placeholder={{i18n
                            "guest_cta.admin.fields.reply_override_inherit"
                          }}
                          {{on
                            "input"
                            (fn this.updateOverride row.index "button_url")
                          }}
                        />
                      </label>
                    </div>
                  </div>
                {{/each}}
              </div>
            {{else}}
              {{! ---------- Popup fields ---------- }}
              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.heading"}}</span>
                <input
                  type="text"
                  value={{this.form.heading}}
                  {{on "input" (fn this.update "heading")}}
                />
              </label>

              <div class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.image"}}</span>
                <UppyImageUploader
                  @id="guest-cta-variant-image"
                  @type="composer"
                  @imageUrl={{this.form.image_url}}
                  @onUploadDone={{fn this.uploadDone "image_url"}}
                  @onUploadDeleted={{fn this.uploadDeleted "image_url"}}
                />
                <input
                  type="text"
                  class="guest-cta-field__url"
                  value={{this.form.image_url}}
                  placeholder={{i18n "guest_cta.admin.fields.image_url_placeholder"}}
                  {{on "input" (fn this.update "image_url")}}
                />
                <small>{{i18n "guest_cta.admin.fields.image_help"}}</small>
              </div>

              <label class="guest-cta-field guest-cta-field--short">
                <span>{{i18n "guest_cta.admin.fields.image_max_width_px"}}</span>
                <input
                  type="number"
                  min="40"
                  max="600"
                  value={{this.form.image_max_width_px}}
                  {{on "input" (fn this.update "image_max_width_px")}}
                />
              </label>

              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.subheading"}}</span>
                <input
                  type="text"
                  value={{this.form.subheading}}
                  {{on "input" (fn this.update "subheading")}}
                />
              </label>

              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.body_text"}}</span>
                <textarea
                  rows="3"
                  value={{this.form.body_text}}
                  {{on "input" (fn this.update "body_text")}}
                ></textarea>
              </label>

              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.button_text"}}</span>
                <input
                  type="text"
                  value={{this.form.button_text}}
                  {{on "input" (fn this.update "button_text")}}
                />
              </label>

              <label class="guest-cta-field">
                <span>{{i18n "guest_cta.admin.fields.button_url"}}</span>
                <input
                  type="text"
                  value={{this.form.button_url}}
                  {{on "input" (fn this.update "button_url")}}
                />
              </label>

              <div class="guest-cta-field-row">
                <label class="guest-cta-field guest-cta-field--short">
                  <span>{{i18n "guest_cta.admin.fields.button_color"}}</span>
                  <span class="guest-cta-color">
                    <input
                      type="color"
                      value={{this.form.button_color}}
                      {{on "input" (fn this.update "button_color")}}
                    />
                    <input
                      type="text"
                      value={{this.form.button_color}}
                      {{on "input" (fn this.update "button_color")}}
                    />
                  </span>
                </label>
                <label class="guest-cta-field guest-cta-field--short">
                  <span>{{i18n "guest_cta.admin.fields.button_text_color"}}</span>
                  <span class="guest-cta-color">
                    <input
                      type="color"
                      value={{this.form.button_text_color}}
                      {{on "input" (fn this.update "button_text_color")}}
                    />
                    <input
                      type="text"
                      value={{this.form.button_text_color}}
                      {{on "input" (fn this.update "button_text_color")}}
                    />
                  </span>
                </label>
              </div>

              <label class="guest-cta-check">
                <input
                  type="checkbox"
                  checked={{this.form.button_glow}}
                  {{on "change" (fn this.updateBool "button_glow")}}
                />
                <span>{{i18n "guest_cta.admin.fields.button_glow"}}</span>
              </label>

              <label class="guest-cta-field guest-cta-field--short">
                <span>{{i18n "guest_cta.admin.fields.show_delay_seconds"}}</span>
                <input
                  type="number"
                  min="0"
                  max="300"
                  step="0.5"
                  value={{this.form.show_delay_seconds}}
                  {{on "input" (fn this.update "show_delay_seconds")}}
                />
                <small>{{i18n "guest_cta.admin.fields.show_delay_seconds_help"}}</small>
              </label>
            {{/if}}

            <label class="guest-cta-check">
              <input
                type="checkbox"
                checked={{this.form.open_in_new_tab}}
                {{on "change" (fn this.updateBool "open_in_new_tab")}}
              />
              <span>{{i18n "guest_cta.admin.fields.open_in_new_tab"}}</span>
            </label>
          </div>

          <div class="guest-cta-variant-modal__preview">
            <span class="guest-cta-variant-modal__preview-label">{{i18n
                "guest_cta.admin.preview"
              }}</span>
            {{#if this.showPreviewPicker}}
              <select
                class="guest-cta-variant-modal__preview-picker"
                {{on "change" this.setPreviewKey}}
              >
                <option
                  value="default"
                  selected={{eq this.previewKey "default"}}
                >{{i18n "guest_cta.admin.fields.reply_preview_default"}}</option>
                {{#each this.overrideRows as |row|}}
                  <option
                    value={{row.key}}
                    selected={{eq this.previewKey row.key}}
                  >{{row.label}}</option>
                {{/each}}
              </select>
            {{/if}}
            <VariantPreview
              @variant={{this.previewVariant}}
              @placement={{this.placement}}
              @message={{if this.isReply this.previewMessage}}
            />
          </div>
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.save}}
          @label="guest_cta.admin.save"
          @isLoading={{this.saving}}
          class="btn-primary"
        />
        <DButton
          @action={{@closeModal}}
          @label="cancel"
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
