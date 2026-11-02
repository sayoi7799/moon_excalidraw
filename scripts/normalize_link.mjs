// `normalizeLink` isn't exported by the package, so this repeats its two lines
// (packages/excalidraw/data/url.ts) around the same pinned sanitize-url.
import { createRequire } from "node:module";

const { sanitizeUrl } = createRequire(import.meta.url)("@braintree/sanitize-url");

export function normalizeLink(link) {
  const trimmed = link.trim();
  if (!trimmed) return trimmed;
  return sanitizeUrl(trimmed.replace(/"/g, "&quot;"));
}
