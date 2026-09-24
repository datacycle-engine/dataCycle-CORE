import SwaggerUIBundle from "swagger-ui-dist/swagger-ui-bundle.js";
import SwaggerUIStandalonePreset from "swagger-ui-dist/swagger-ui-standalone-preset.js";
import "swagger-ui-dist/swagger-ui.css";
// This page ships no application bundle, so the icon font comes with it: the sidebar
// markup uses fa-search/fa-times/fa-moon-o and sidebar.css and swagger_theme.css set
// `font-family: FontAwesome` on ::before glyphs. Same module application.scss loads.
import "../stylesheets/modules/_font-awesome.scss";
import "../stylesheets/openapi_viewer.css";
import { initCommandPalette, teardownCommandPalette, cssEscape } from "./openapi_command_palette.js";

// Reads the CSRF token from the meta tag so the same-origin spec fetch and
// "Try it out" requests are accepted by Rails' forgery protection.
function csrfToken() {
	return document.querySelector("meta[name='csrf-token']")?.content;
}

// Builds the spec URL for the given locale, keeping the request on the same
// origin so the browser sends the existing session cookie.
function specUrl(baseUrl, language) {
	const url = new URL(baseUrl, window.location.origin);
	if (language) url.searchParams.set("language", language);
	return url.pathname + url.search;
}

// Slugifies a nav label into a stable id for the anchor target.
function slug(text) {
	return `ov-sec-${text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "")}`;
}

// The tag name of a Swagger `.opblock-tag` header (from its data-tag, falling
// back to the rendered label text).
function tagLabel(tagEl) {
	return (tagEl?.getAttribute("data-tag") || tagEl?.querySelector("a span, span")?.textContent || "").trim();
}

// Sidebar icon per known spec tag (FontAwesome 4 names); unknown tags fall
// back to the generic cube.
const TAG_ICONS = {
	contents: "fa-file-text-o",
	delivery: "fa-paper-plane",
	suggest: "fa-lightbulb-o",
	facets: "fa-filter",
	statistics: "fa-bar-chart",
	timeseries: "fa-line-chart",
	elevation: "fa-area-chart",
	downloads: "fa-download",
	classifications: "fa-tags",
	collections: "fa-folder-open-o",
	authentication: "fa-lock",
};

// Sidebar metadata from the spec: operation counts per tag, schema count and
// the tag hierarchy (tags carrying the x-parent vendor extension become
// sub-items of their parent). Derived from the spec (not the DOM): Swagger
// mounts collapsed sections lazily, so their children can't be counted reliably.
function sidebarMeta(spec) {
	const byTag = {};
	Object.values(spec?.paths || {}).forEach((item) => {
		Object.values(item).forEach((op) => {
			const tag = Array.isArray(op?.tags) ? op.tags[0] : undefined;
			if (tag) byTag[tag] = (byTag[tag] || 0) + 1;
		});
	});

	const parents = {};
	(spec?.tags || []).forEach((tag) => {
		if (tag?.name && tag["x-parent"]) parents[tag.name] = tag["x-parent"];
	});

	return { byTag, parents, schemas: Object.keys(spec?.components?.schemas || {}).length };
}

// Nests the child tag sections in the main reference under their parent,
// mirroring the sidebar hierarchy on the page itself. Tags carrying the
// `x-parent` vendor extension (the Delivery groups — Suggest/Facets/Statistics/
// Timeseries/Downloads) are indented behind a guide line, and the parent header
// (Delivery) gets a toggle that shows/hides them (open by default). Idempotent:
// guarded by the toggle it inserts, so Swagger re-renders don't duplicate it.
function nestTagSections(root, meta = {}, labels = {}) {
	const parents = meta.parents || {};
	if (!Object.keys(parents).length) return;

	// map every rendered tag section by its label
	const sectionByTag = {};
	root.querySelectorAll(".opblock-tag-section").forEach((section) => {
		const tagEl = section.querySelector(".opblock-tag");
		const label = tagLabel(tagEl);
		if (label) sectionByTag[label] = { section, tagEl };
	});

	// mark each child section and collect the children per parent
	const childrenByParent = {};
	Object.entries(parents).forEach(([child, parent]) => {
		const childEntry = sectionByTag[child];
		if (!childEntry || !sectionByTag[parent]) return;
		// mark via data attribute (not a class): the indent CSS keys off it and it
		// survives Swagger's className rewrites on expand/collapse (see CSS note).
		childEntry.section.dataset.ovParent = parent;
		(childrenByParent[parent] ||= []).push(childEntry.section);
	});

	// Turn each parent header (Delivery) into the single group control: clicking
	// anywhere on it folds the WHOLE group — Delivery's own operations (hidden via
	// the ov-group-collapsed class + CSS) plus every child section. We take over
	// the header click (capture + stopPropagation) so Swagger's native per-section
	// collapse never fires, which lets us hide its now-redundant right-hand arrow.
	Object.keys(childrenByParent).forEach((parent) => {
		const entry = sectionByTag[parent];
		const tagEl = entry?.tagEl;
		const section = entry?.section;
		if (!tagEl || !section || tagEl.querySelector(".ov-group-toggle")) return; // already wired
		tagEl.classList.add("ov-tag-has-group");

		// chevron: purely the visual affordance — the header itself is the target.
		// Placed directly right of the tag label (Swagger's growing <small>/<div>
		// spacers keep it hugging the text); the header stays the click target.
		const toggle = document.createElement("span");
		toggle.className = "ov-group-toggle";
		toggle.setAttribute("aria-hidden", "true");
		toggle.innerHTML = '<i class="fa fa-chevron-down" aria-hidden="true"></i>';
		const label = tagEl.querySelector("a.nostyle") || tagEl.querySelector("a") || tagEl.firstElementChild;
		if (label) label.after(toggle);
		else tagEl.insertBefore(toggle, tagEl.firstChild);

		tagEl.setAttribute("role", "button");
		tagEl.setAttribute("tabindex", "0");
		tagEl.setAttribute("aria-expanded", "true");
		if (labels.toggleGroup) tagEl.setAttribute("aria-label", labels.toggleGroup);

		const setExpanded = (expanded) => {
			tagEl.setAttribute("aria-expanded", expanded ? "true" : "false");
			section.classList.toggle("ov-group-collapsed", !expanded);
			childrenByParent[parent].forEach((child) => { child.hidden = !expanded; });
		};
		const toggleGroup = (event) => {
			event.preventDefault();
			event.stopPropagation();
			setExpanded(tagEl.getAttribute("aria-expanded") !== "true");
		};

		tagEl.addEventListener("click", toggleGroup, true); // capture: pre-empt Swagger
		tagEl.addEventListener("keydown", (event) => {
			if (event.key === "Enter" || event.key === " ") toggleGroup(event);
		});
	});
}

// Collects the sections Swagger UI rendered (overview, one per tag, schemas)
// so we can drive the custom dataCycle sidebar from the real DOM.
function collectSections(root, labels, meta = {}) {
	const sections = [];

	const info = root.querySelector(".information-container");
	if (info) sections.push({ label: labels.overview, el: info, icon: "fa-home" });

	root.querySelectorAll(".opblock-tag").forEach((tagEl) => {
		const label = tagLabel(tagEl);
		if (!label) return;
		sections.push({
			label,
			el: tagEl.closest(".opblock-tag-section") || tagEl,
			icon: TAG_ICONS[label.toLowerCase()] || "fa-cube",
			anchor: tagEl,
			count: meta.byTag?.[label],
			parent: meta.parents?.[label],
		});
	});

	const models = root.querySelector("section.models");
	if (models) sections.push({ label: labels.schemas, el: models, icon: "fa-sitemap", count: meta.schemas, divider: true });

	return sections;
}

// When a nav target lives inside a collapsed group (see nestTagSections), expand
// that group so the subsequent scroll lands on a visible section. Reads the live
// DOM, so it works regardless of build order between sidebar and nesting.
function revealTarget(target) {
	const childSection = target.closest?.(".opblock-tag-section[data-ov-parent]");
	if (!childSection || !childSection.hidden) return;
	const parent = childSection.dataset.ovParent;
	if (!parent) return;
	// the header carries aria-expanded and the toggle handler; clicking it expands
	document.querySelector(`.opblock-tag[data-tag="${cssEscape(parent)}"][aria-expanded="false"]`)?.click();
}

// Renders the sidebar nav links and wires smooth-scroll + scroll-spy so the
// active section is highlighted as the user scrolls the reference.
function buildSidebar(sections) {
	const nav = document.getElementById("ov-nav");
	if (!nav || !sections.length) return;

	nav.innerHTML = "";
	const linkByLabel = {};
	const links = sections.map((section) => {
		const target = section.anchor || section.el;
		target.id ||= slug(section.label);

		if (section.divider) {
			const divider = document.createElement("span");
			divider.className = "ov-nav-divider";
			divider.setAttribute("aria-hidden", "true");
			nav.appendChild(divider);
		}

		const link = document.createElement("a");
		link.className = section.parent ? "ov-nav-item ov-nav-item--child" : "ov-nav-item";
		link.href = `#${target.id}`;
		const icon = document.createElement("i");
		icon.className = `fa ${section.icon}`;
		icon.setAttribute("aria-hidden", "true");
		const label = document.createElement("span");
		label.textContent = section.label;
		link.appendChild(icon);
		link.appendChild(label);
		if (section.count) {
			const count = document.createElement("span");
			count.className = "ov-nav-count";
			count.textContent = section.count;
			link.appendChild(count);
		}
		link.addEventListener("click", (event) => {
			event.preventDefault();
			revealTarget(target); // expand the parent group if the child section is collapsed
			target.scrollIntoView({ behavior: "smooth", block: "start" });
			history.replaceState(null, "", `#${target.id}`);
		});
		nav.appendChild(link);
		linkByLabel[section.label] = link;
		return { link, el: section.el, parent: section.parent };
	});

	// resolve each sub-item's parent link so the scroll-spy can co-highlight it
	links.forEach((entry) => {
		entry.parentLink = entry.parent ? linkByLabel[entry.parent] : null;
	});

	setupScrollSpy(links);
}

// Swagger UI's onComplete can fire before the tag sections finish mounting, so
// poll (bounded) until they appear, then build the sidebar once.
function buildSidebarWhenReady(mount, labels, meta, attempts = 0) {
	const root = mount.querySelector(".swagger-ui");
	const ready = root && root.querySelector(".opblock-tag");
	if (ready || attempts >= 60) {
		if (root) {
			buildSidebar(collectSections(root, labels, meta));
			nestTagSections(root, meta, labels);
		}
	} else {
		window.setTimeout(() => buildSidebarWhenReady(mount, labels, meta, attempts + 1), 150);
	}
}

// Colors each HTTP status code by class (2xx green, 3xx blue, 4xx/5xx red) for
// both documented and live responses. Marks handled cells so the observer that
// calls this does not loop on its own style mutations.
function colorResponseStatuses(root) {
	root.querySelectorAll(".response-col_status:not([data-ov-status])").forEach((el) => {
		const code = parseInt(el.textContent, 10);
		if (!code) return;
		el.dataset.ovStatus = "1";
		el.style.color = code < 300 ? "var(--ov-ok)" : code < 400 ? "var(--ov-info)" : "var(--ov-err)";
	});
}

// Compacts parameter/property descriptions: keeps the first paragraph visible
// and tucks any following detail/example paragraphs behind an info (ⓘ) toggle,
// so the parameter/schema tables stay scannable. Idempotent — each description
// is marked so re-runs (and Swagger's React re-renders) don't double-process.
function enhanceDescriptions(root, labels) {
	// Positively scope to attribute descriptions only: the parameter table and
	// the json-schema model tree (query/body schemas). This avoids the API info
	// and operation-level descriptions without an ancestor blocklist — Swagger
	// wraps the request body in .opblock-description-wrapper, so an exclude-based
	// approach wrongly skipped the ContentQuery model fields.
	const scope =
		".parameters-col_description .renderedMarkdown:not([data-ov-desc]), " +
		".json-schema-2020-12 .renderedMarkdown:not([data-ov-desc])";
	root.querySelectorAll(scope).forEach((md) => {
		if (md.closest(".ov-desc-detail")) return; // don't recurse into moved detail
		const first = md.firstElementChild;
		// Don't mark it yet when there's nothing to fold: some renderers (the
		// json-schema model tree) add later elements in a separate render pass,
		// so marking "skip" now would exclude it forever once the detail arrives.
		// Leaving it unmarked lets a later observer pass re-evaluate it.
		// (Everything after the first element counts as detail — matching the CSS
		// rule that pre-hides it, so nothing flashes before this handler runs.)
		if (!first || !first.nextElementSibling) return;
		md.dataset.ovDesc = "1";
		md.classList.add("ov-desc");

		// move everything after the first element into a collapsible detail box
		const detail = document.createElement("span");
		detail.className = "ov-desc-detail";
		let node = first.nextSibling;
		while (node) {
			const next = node.nextSibling;
			detail.appendChild(node);
			node = next;
		}

		const btn = document.createElement("button");
		btn.type = "button";
		btn.className = "ov-info-toggle";
		btn.setAttribute("aria-expanded", "false");
		btn.setAttribute("aria-label", labels.details);
		btn.title = labels.details;
		// inline SVG (not a FontAwesome glyph) so the icon always renders,
		// independent of the icon font loading inside the Swagger UI scope
		btn.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M11 7h2v2h-2zm0 4h2v6h-2zm1-9C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/></svg>';
		btn.addEventListener("click", (event) => {
			event.preventDefault();
			event.stopPropagation();
			const open = md.classList.toggle("ov-open");
			btn.setAttribute("aria-expanded", open ? "true" : "false");
		});

		first.appendChild(btn);
		md.appendChild(detail);
	});
}

// Shows only the "Schema" tab in the default view: the "Example Value" tab is hidden
// and Schema activated. Swagger renders only the active tab's panel, so hiding via CSS
// is not enough. Exception: while try-it-out is active (the Cancel button is visible)
// the request-body tab is left alone, or "Edit Value" — and with it the body — would not
// be editable (#50201 §6).
//
// Runs over ALL tabs on EVERY MutationObserver pass, rather than marking each tab once
// with data-ov-schema: Swagger/React sometimes reuses the same tab node across
// try-it-out → Cancel, and a one-shot marker would then skip it, so the "Example Value"
// box reappeared after cancelling. The `if (!active) click` guard keeps the call
// idempotent and loop-free — with Model already active nothing happens, so there is no
// second click and no loop.
function forceSchemaTabs(root) {
	root.querySelectorAll(".tab").forEach((tab) => {
		const modelBtn = tab.querySelector("button[data-name='model']");
		if (!modelBtn) return; // no schema tab here — nothing to switch
		if (
			tab.closest(".opblock-section-request-body") &&
			tab.closest(".opblock")?.querySelector(".try-out__btn.cancel")
		)
			return;
		const exampleItem = tab.querySelector("button[data-name='example']")?.closest("li");
		if (exampleItem) exampleItem.style.display = "none";
		if (!modelBtn.closest("li")?.classList.contains("active")) modelBtn.click();
	});
}

function directChildByClass(element, className) {
	return Array.from(element?.children || []).find((child) => child.classList.contains(className));
}

function isJsonSchemaCollapsed(schemaEl) {
	return directChildByClass(schemaEl, "json-schema-2020-12-body")?.classList.contains(
		"json-schema-2020-12-body--collapsed",
	);
}

function setJsonSchemaCollapsed(schemaEl, collapsed, deep = false) {
	const schemas = deep ? [schemaEl, ...schemaEl.querySelectorAll(".json-schema-2020-12")] : [schemaEl];

	schemas.forEach((schema) => {
		const head = directChildByClass(schema, "json-schema-2020-12-head");
		const body = directChildByClass(schema, "json-schema-2020-12-body");
		const accordion = head?.querySelector(".json-schema-2020-12-accordion");
		const icon = accordion?.querySelector(".json-schema-2020-12-accordion__icon");
		const deepButton = head?.querySelector(".json-schema-2020-12-expand-deep-button");

		body?.classList.toggle("json-schema-2020-12-body--collapsed", collapsed);
		accordion?.setAttribute("aria-expanded", collapsed ? "false" : "true");
		icon?.classList.toggle("json-schema-2020-12-accordion__icon--expanded", !collapsed);
		icon?.classList.toggle("json-schema-2020-12-accordion__icon--collapsed", collapsed);
		if (deepButton) deepButton.textContent = collapsed ? "Expand all" : "Collapse all";
	});
}

// Endpoint request/response schemas render their full tree in the DOM
// (defaultModelExpandDepth: 4) so opening a model shows the same content as before
// — we only want each one to START closed, nothing else changed.
//
// We collapse through Swagger's OWN controls (a real click), not by toggling
// classes: Swagger/React owns this DOM and re-renders from its internal expand
// state, so directly setting the collapsed class desynced (the button kept saying
// "Collapse all", content flashed in and vanished, models stayed empty).
//
// The click targets the "Collapse all" deep button, not the plain accordion: the
// accordion only closes the OUTER body while every nested level stays expanded in
// React's state, so a later title click reveals the whole tree at once. The deep
// button collapses EVERY level, exactly like a manual "Expand all" -> "Collapse
// all" — so afterwards clicking the title opens only the first level, which is the
// behaviour we want. We click it only while the model is still expanded at the top
// (its fresh render state), where the deep button means "Collapse all"; that avoids
// ever triggering a deep EXPAND. Falls back to the accordion if no deep button.
//
// data-ov-initial-collapsed marks each model the moment we act on it (set BEFORE
// the click so the mutation it triggers can't re-enter), so the MutationObserver
// never re-collapses a model the user has since opened. Scoped to .opblock so the
// bottom Schemas section (its own depth-1 list) is untouched.
function collapseInitialSchemas(root) {
	root.querySelectorAll(".opblock .json-schema-2020-12").forEach((model) => {
		if (model.dataset.ovInitialCollapsed) return;
		// Only top-level models — nested schemas collapse with their parent.
		if (model.parentElement?.closest(".json-schema-2020-12")) return;
		// Already collapsed (e.g. Swagger rendered it closed): just mark and skip.
		if (isJsonSchemaCollapsed(model)) {
			model.dataset.ovInitialCollapsed = "1";
			return;
		}
		const head = directChildByClass(model, "json-schema-2020-12-head");
		// Prefer the deep "Collapse all" button so nested levels collapse too;
		// fall back to the accordion (closes at least the outer body).
		const toggle =
			head?.querySelector(".json-schema-2020-12-expand-deep-button") ||
			head?.querySelector(".json-schema-2020-12-accordion");
		if (!toggle) return; // no control here — leave it as Swagger rendered it
		model.dataset.ovInitialCollapsed = "1";
		toggle.click();
	});
}

// Live responses and lazily-expanded operation bodies render after onComplete,
// so watch the tree and (debounced) recolor statuses + compact descriptions.
function watchDom(root, labels) {
	let queued = false;
	const run = () => {
		queued = false;
		colorResponseStatuses(root);
		enhanceDescriptions(root, labels);
	};
	run();
	forceSchemaTabs(root);
	collapseInitialSchemas(root);
	const observer = new MutationObserver(() => {
		// forceSchemaTabs runs SYNCHRONOUSLY here (not on the debounced path below):
		// the observer callback is a microtask, so it fires BEFORE the browser
		// paints. On a Try-it-out → Cancel, Swagger re-renders the request body with
		// the "Example Value" box visible again; forcing the tab back to "Schema" on
		// the 60ms setTimeout let that box paint for one frame and then collapse back
		// to Schema — the field visibly "pulled in" and settled. Switching pre-paint
		// swaps the tab before that intermediate frame is ever shown, so there's no
		// flash. It stays idempotent (only clicks when Schema isn't already active),
		// so the click's own mutations converge instead of looping.
		forceSchemaTabs(root);
		// Pre-paint, same as forceSchemaTabs: operation bodies render lazily on
		// expand, so a model's full tree only appears here — collapse it before it
		// can paint open.
		collapseInitialSchemas(root);
		if (queued) return;
		queued = true;
		window.setTimeout(run, 60);
	});
	observer.observe(root, { childList: true, subtree: true });
	return observer;
}

// The scroll-spy listener is kept module-side so a prior one is removed before a
// new sidebar build adds another, preventing accumulation across re-renders.
let scrollSpyHandler = null;

// Detaches the current scroll-spy listener (re-init and SPA teardown).
function teardownScrollSpy() {
	if (!scrollSpyHandler) return;
	window.removeEventListener("scroll", scrollSpyHandler);
	scrollSpyHandler = null;
}

// Highlights the nav item whose section is currently at the top of the
// viewport; the parent of an active sub-item is co-highlighted for context.
function setupScrollSpy(links) {
	let ticking = false;
	const update = () => {
		ticking = false;
		let activeIndex = 0;
		links.forEach(({ el }, index) => {
			const rect = el.getBoundingClientRect();
			if (rect.height === 0) return;
			if (rect.top <= 140) activeIndex = index;
		});
		const activeParent = links[activeIndex]?.parentLink || null;
		links.forEach(({ link }, index) => {
			link.classList.toggle("is-active", index === activeIndex);
			link.classList.toggle("is-child-active", link === activeParent);
		});
	};

	teardownScrollSpy();
	scrollSpyHandler = () => {
		if (ticking) return;
		ticking = true;
		window.requestAnimationFrame(update);
	};
	window.addEventListener("scroll", scrollSpyHandler, { passive: true });
	update();
}

// Fetches the OpenAPI document with the existing session. `no-store` keeps the
// browser from serving a stale spec from cache: the URL is stable per locale, so
// a cached response would otherwise hide server-side spec changes on reload.
async function loadSpec(url, labels) {
	const res = await fetch(url, {
		credentials: "same-origin",
		cache: "no-store",
		headers: { Accept: "application/json" },
	});

	if (!res.ok) {
		if (res.status === 401) {
			window.location.href = `/users/sign_in?redirect_to=${encodeURIComponent(window.location.pathname + window.location.search)}`;
			return;
		} else if (res.status === 403) {
			throw new Error(labels.accessDenied);
		}
		throw new Error(labels.specError);
	}

	return res.json();
}

// Neutralizes schemas that Swagger UI cannot render without freezing the tab.
// Any schema with many oneOf branches (e.g. 80+ entity types) causes
// operation-expand to lock up the browser. We collapse heavy schemas to
// light placeholders — individual schemas stay browsable in the Schemas section.
// Root cause lives in the spec (#50127/#50131).
function lightenHeavySchemas(spec) {
	const schemas = spec?.components?.schemas;
	if (!schemas) return spec;

	// Read threshold from mount (set by controller); default to 8 if not provided
	const threshold = parseInt(document.querySelector("#swagger-ui")?.dataset.heavySchemaThreshold || "8", 10);

	Object.entries(schemas).forEach(([name, schema]) => {
		if (Array.isArray(schema?.oneOf) && schema.oneOf.length > threshold) {
			schemas[name] = {
				type: "object",
				title: name,
				description:
					schema.description ||
					`One of ${schema.oneOf.length} types — browse them individually in the Schemas section.`,
				additionalProperties: true,
			};
		}
	});

	return spec;
}

// A linked property documents both shapes the API can deliver: the { @id, @type } stub
// returned by default, and the full target entity that include/fields expands it to.
// Inlining the targets is what makes the Schemas tree explode -- targets link back, so
// one ProtectedArea reached ~115k rendered nodes at expand depth 4 and froze the tab.
// The served document keeps both (it is the contract, and /schema reads the targets
// from it); here we keep the stub and name the targets in its description instead.
function stubLinkedTargets(spec, expandableTo) {
	const walk = (node) => {
		if (Array.isArray(node)) return node.forEach(walk);
		if (!node || typeof node !== "object") return;

		const branches = node.oneOf;
		if (Array.isArray(branches)) {
			const stub = branches.find((b) => b?.$ref?.endsWith("/EntityReference"));
			const targets = branches
				.filter((b) => b !== stub && b?.$ref)
				.map((b) => b.$ref.split("/").pop());

			if (stub && targets.length) {
				node.oneOf = undefined;
				delete node.oneOf;
				node.$ref = stub.$ref;
				node.description = [node.description, `${expandableTo}: ${targets.join(", ")}`]
					.filter(Boolean)
					.join(" — ");
				return; // the stub has no branches left to walk
			}
		}

		Object.values(node).forEach(walk);
	};

	walk(spec?.components?.schemas);
	return spec;
}

// Renders a plain error message into the mount when the spec cannot be loaded.
function renderSpecError(mount, message) {
	const div = document.createElement("div");
	div.className = "openapi-viewer-loading";
	div.textContent = message;
	mount.innerHTML = "";
	mount.appendChild(div);
}

// Boots Swagger UI on the mount element and wires session-based auth: the spec
// is fetched from GET /api/config/openapi (data-spec-url) with the CSRF header,
// lightened, then handed to Swagger; requests run with same-origin credentials
// so no manual token is needed. On render it builds the dataCycle sidebar.
export default function initOpenApiViewer(selector = "#swagger-ui") {
	const mount = document.querySelector(selector);
	if (!mount) return;

	const baseUrl = mount.dataset.specUrl;
	if (!baseUrl) return;

	const language = mount.dataset.language || document.documentElement.lang;
	const url = specUrl(baseUrl, language);
	const labels = {
		overview: mount.dataset.labelOverview || "Overview",
		schemas: mount.dataset.labelSchemas || "Schemas",
		details: mount.dataset.labelDetails || "Details",
		accessDenied: mount.dataset.labelAccessDenied || "Access denied.",
		specError: mount.dataset.labelSpecError || "Could not load the API description.",
		toggleGroup: mount.dataset.labelToggleGroup || "Toggle sub-groups",
		expandableTo: mount.dataset.labelExpandableTo || "Expandable via include/fields to",
	};

	let statusObserver = null;

	loadSpec(url, labels)
		.then((spec) => {
			if (!spec) return; // 401 → loadSpec already redirected to sign-in
			SwaggerUIBundle({
				domNode: mount,
				spec: stubLinkedTargets(lightenHeavySchemas(spec), labels.expandableTo),
				presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
				layout: "BaseLayout",
				deepLinking: true,
				// Try-it-out stays available via its button but starts read-only —
				// no "Edit Value" fields in the default view (#50201).
				tryItOutEnabled: false,
				withCredentials: true,
				docExpansion: "list",
				// Bottom Schemas section stays a compact list (depth 1) so all schemas
				// aren't rendered eagerly. Endpoint request/response schemas render the
				// FULL nested envelope tree into the DOM (depth 4) — not to show it
				// open, but so the native "Expand all" button has real nodes to reveal:
				// at a low depth Swagger never renders the nested $refs, so the button
				// toggled nothing. collapseInitialSchemas() then closes each model once
				// at render time, so they START collapsed and expand on demand.
				// Capped at 4: depth 6 renders too many nodes and freezes the tab even
				// while collapsed (the heavy oneOf schemas, #50127/#50131).
				defaultModelsExpandDepth: 1,
				defaultModelExpandDepth: 4,
				defaultModelRendering: "model",
				requestInterceptor: (request) => {
					const token = csrfToken();
					if (token) request.headers["X-CSRF-Token"] = token;
					request.credentials = "same-origin";
					return request;
				},
				onComplete: () => {
					buildSidebarWhenReady(mount, labels, sidebarMeta(spec));
					// The palette indexes the spec (endpoints + schemas) and navigates
					// the live DOM on select; safe to wire up once Swagger has rendered.
					initCommandPalette(mount, spec, labels);
					// Observe the stable mount (#swagger-ui): the inner `.swagger-ui`
					// may not exist yet when onComplete fires, so querying it here can
					// return null and skip the observer entirely.
					statusObserver = watchDom(mount, labels);
				},
			});
		})
		.catch((error) => renderSpecError(mount, error.message));

	// Return cleanup function for SPA contexts
	return () => {
		statusObserver?.disconnect();
		teardownScrollSpy();
		teardownCommandPalette();
	};
}
