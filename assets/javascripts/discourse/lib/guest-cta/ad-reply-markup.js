import { escapeHtml } from "./popup-markup";

// Markup of the guest reply, shared by the live component and the admin
// previews. It mirrors the structure of a Discourse post (topic-avatar, then
// topic-body holding topic-meta-data, cooked and the post menu) so the
// forum's theme styles it like any other reply, and every element also
// carries an `ad-reply` class so it can be told apart (by us and by anyone
// else) from real posts.

const AVATAR_SIZE = 45;

// The message a visitor sees: the variant's default, or the override for the
// topic's category (or that category's parent). Blank override fields
// inherit the default.
export function resolveReplyMessage(variant, categoryId, parentCategoryId) {
  const base = {
    reply_cooked: variant.reply_cooked || "",
    button_text: variant.button_text || "",
    button_url: variant.button_url || "",
  };
  const overrides = variant.reply_category_overrides || [];
  const ids = [categoryId, parentCategoryId].filter(Boolean).map(Number);
  const match =
    ids.length &&
    overrides.find((o) =>
      (o.category_ids || []).some((id) => ids.includes(Number(id)))
    );
  return match ? applyOverride(base, match) : base;
}

export function applyOverride(base, override) {
  const hasButton = override.button_text || override.button_url;
  return {
    reply_cooked: override.reply_cooked || base.reply_cooked,
    button_text: hasButton ? override.button_text || "" : base.button_text,
    button_url: hasButton ? override.button_url || "" : base.button_url,
  };
}

function buttonHtml(message, preview) {
  if (!message.button_text || !message.button_url) {
    return "";
  }
  const href = preview ? "#" : escapeHtml(message.button_url);
  const extra = preview ? ` tabindex="-1"` : "";
  return `
      <p class="ad-reply__button-row">
        <a class="btn btn-primary ad-reply__button" href="${href}"${extra}>${escapeHtml(message.button_text)}</a>
      </p>`;
}

// Like count under the message, laid out like a post's menu row. Hidden at 0.
function likesHtml(variant) {
  const count = parseInt(variant.reply_like_count, 10) || 0;
  if (count <= 0) {
    return "";
  }
  return `
      <section class="post-menu-area clearfix ad-reply__menu">
        <nav class="post-controls ad-reply__controls">
          <div class="actions ad-reply__actions">
            <span class="like-count highlight-action ad-reply__like-count">${count.toLocaleString()}</span>
            <span class="like ad-reply__like"><svg class="fa d-icon d-icon-heart svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#heart"></use></svg></span>
          </div>
        </nav>
      </section>`;
}

// Inner HTML of the reply row: avatar column, then body with the author line,
// the message, the optional button and the like count. The name and photo are
// whatever the admin set; the name is plain text and links nowhere. The
// cooked HTML comes from the server (PrettyText, the same sanitiser posts
// use) or, in the editor's live preview, from the browser's Markdown engine;
// it is inserted as-is and nothing else in the variant is trusted.
//
// `message` is what resolveReplyMessage returned; it defaults to the
// variant's default message.
export function adReplyInnerHtml(variant, message = null, { preview = false } = {}) {
  const msg = message || resolveReplyMessage(variant, null, null);
  const name = escapeHtml(variant.reply_name || "");
  const src = escapeHtml(variant.reply_avatar_url || "");
  const avatar = src
    ? `<img alt="" width="${AVATAR_SIZE}" height="${AVATAR_SIZE}" src="${src}" class="avatar" loading="lazy" />`
    : `<span class="avatar ad-reply__avatar-placeholder"></span>`;

  return `
    <div class="topic-avatar ad-reply__avatar">
      <div class="post-avatar">${avatar}</div>
    </div>
    <div class="topic-body ad-reply__body">
      <div class="topic-meta-data ad-reply__meta">
        <div class="names ad-reply__names">
          <span class="first username ad-reply__name">${name}</span>
        </div>
      </div>
      <div class="contents ad-reply__contents">
        <div class="cooked ad-reply__cooked">${msg.reply_cooked || ""}</div>${buttonHtml(msg, preview)}
      </div>${likesHtml(variant)}
    </div>
  `;
}

// Short plain-text summary of the message for the results tables.
export function adReplySummary(variant, max = 90) {
  const text = String(variant.reply_raw || "")
    .replace(/!\[[^\]]*\]\([^)]*\)/g, "")
    .replace(/\s+/g, " ")
    .trim();
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}
