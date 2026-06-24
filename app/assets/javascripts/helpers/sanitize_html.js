// Client-side HTML sanitizer mirroring the server-side ``full`` allowlist in
// ``DataCycleCore::MasterData::DataConverter`` (SANITIZE_TAGS[:full] /
// SANITIZED_ATTRIBUTES[:full]). Used before assigning untrusted markup to
// ``innerHTML`` sinks (e.g. tooltips) to prevent stored/DOM XSS.

// Keep these in sync with DataConverter's :full mode.
const ALLOWED_TAGS = new Set([
	"b",
	"strong",
	"i",
	"em",
	"h1",
	"h2",
	"h3",
	"h4",
	"u",
	"blockquote",
	"ul",
	"ol",
	"li",
	"br",
	"a",
	"contentlink",
	"p",
	"sub",
	"sup",
	"span",
	"div",
]);
const ALLOWED_ATTRIBUTES = new Set([
	"href",
	"target",
	"rel",
	"class",
	"data-href",
	"data-dc-tooltip",
	"data-dc-tooltip-id",
]);
// Attributes whose value is a URL and must be protocol-checked.
const URL_ATTRIBUTES = new Set(["href", "data-href"]);
const ALLOWED_PROTOCOLS = new Set(["http:", "https:", "mailto:", "tel:"]);

function safeUrl(value) {
	// Relative URLs resolve against the current origin (http/https) and pass.
	const anchor = document.createElement("a");
	anchor.href = value;
	return ALLOWED_PROTOCOLS.has(anchor.protocol) ? value : null;
}

function sanitizeInto(source, target) {
	for (const child of Array.from(source.childNodes)) {
		if (child.nodeType === Node.TEXT_NODE) {
			target.appendChild(document.createTextNode(child.textContent));
			continue;
		}
		if (child.nodeType !== Node.ELEMENT_NODE) continue;

		const tag = child.tagName.toLowerCase();

		if (!ALLOWED_TAGS.has(tag)) {
			// Disallowed tags are unwrapped (tag + its attributes dropped), keeping
			// their sanitized children as text — mirroring Rails' ``sanitize``.
			sanitizeInto(child, target);
			continue;
		}

		const clean = document.createElement(tag);
		for (const attr of Array.from(child.attributes)) {
			const name = attr.name.toLowerCase();
			if (!ALLOWED_ATTRIBUTES.has(name)) continue;

			if (URL_ATTRIBUTES.has(name)) {
				const url = safeUrl(attr.value);
				if (url === null) continue;
				clean.setAttribute(name, url);
			} else {
				clean.setAttribute(name, attr.value);
			}
		}

		sanitizeInto(child, clean);
		target.appendChild(clean);
	}
}

// Returns a sanitized HTML string safe to assign to ``innerHTML``.
export function sanitizeHtml(html) {
	if (!html) return "";

	const doc = new DOMParser().parseFromString(String(html), "text/html");
	const container = document.createElement("div");
	sanitizeInto(doc.body, container);

	return container.innerHTML;
}

export default sanitizeHtml;
