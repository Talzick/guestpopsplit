import { escapeHtml } from "./popup-markup";

// Markup of the guest reply, shared by the live component and the admin
// previews. It mirrors the structure of a Discourse post (topic-avatar, then
// topic-body holding topic-meta-data and cooked) so the forum's theme styles
// it like any other reply, and every element also carries an `ad-reply` class
// so it can be told apart (by us and by anyone else) from real posts.

const AVATAR_SIZE = 45;

// Inner HTML of the reply row: avatar column, then body with the author line
// and the message. The name and photo are whatever the admin set; the name is
// plain text and links nowhere. The cooked HTML comes from the server
// (PrettyText, the same sanitiser posts use) or, in the editor's live
// preview, from the browser's Markdown engine; it is inserted as-is and
// nothing else in the variant is trusted.
export function adReplyInnerHtml(variant) {
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
        <div class="cooked ad-reply__cooked">${variant.reply_cooked || ""}</div>
      </div>
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
