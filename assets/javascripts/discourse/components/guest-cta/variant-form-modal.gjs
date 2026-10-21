import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { cook } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
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
const REPLY_FIELDS = ["reply_name", "reply_avatar_url", "reply_raw", "open_in_new_tab"];

const PREVIEW_DEBOUNCE_MS = 350;

// Edit form for the baseline or a test variant, with a live preview.
//
// @model: { variant, placement, url, method, testId, isBaseline, title, onSaved }
export default class VariantFormModal extends Component {
  @tracked form;
  @tracked saving = false;
  @tracked flash = null;

  // Reply only: the preview needs the message cooked, which happens a moment
  // after the admin stops typing.
  @tracked previewCooked = "";
  #cookTimer = null;

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
    this.form = form;

    if (this.isReply) {
      this.previewCooked = source.reply_cooked || "";
      if (!this.previewCooked && form.reply_raw) {
        this.recook();
      }
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearTimeout(this.#cookTimer);
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
  // message, which the server will produce on save.
  get previewVariant() {
    if (!this.isReply) {
      return this.form;
    }
    return { ...this.form, reply_cooked: this.previewCooked };
  }

  scheduleRecook() {
    clearTimeout(this.#cookTimer);
    this.#cookTimer = setTimeout(() => this.recook(), PREVIEW_DEBOUNCE_MS);
  }

  async recook() {
    const raw = this.form.reply_raw || "";
    if (!raw.trim()) {
      this.previewCooked = "";
      return;
    }
    try {
      const cooked = await cook(raw);
      if (!this.isDestroying && this.form.reply_raw === raw) {
        this.previewCooked = cooked.toString();
      }
    } catch {
      // The preview is best-effort; the server cooks the real thing on save.
    }
  }

  @action
  update(field, event) {
    this.form = { ...this.form, [field]: event.target.value };
    if (field === "reply_raw") {
      this.scheduleRecook();
    }
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
    this.scheduleRecook();
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
    const data = { variant: this.form, placement: this.placement };
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
            <VariantPreview
              @variant={{this.previewVariant}}
              @placement={{this.placement}}
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
