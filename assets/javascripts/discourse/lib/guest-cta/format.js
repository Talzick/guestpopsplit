export function formatNumber(value) {
  return Number(value || 0).toLocaleString();
}

export function formatPercent(value) {
  return `${Number(value || 0).toFixed(2)}%`;
}

export function formatSignedPercent(value) {
  if (value === null || value === undefined) {
    return "–";
  }
  const n = Number(value);
  return `${n > 0 ? "+" : ""}${n.toFixed(1)}%`;
}

export function formatDate(value) {
  if (!value) {
    return "";
  }
  // A bare "YYYY-MM-DD" would otherwise be parsed as UTC midnight and can
  // show as the previous day in western timezones.
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value));
  const date = dateOnly
    ? new Date(+dateOnly[1], +dateOnly[2] - 1, +dateOnly[3])
    : new Date(value);
  return date.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}
