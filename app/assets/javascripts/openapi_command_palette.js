// dataCycle OpenAPI viewer — command palette for the sidebar search (#50192).
// Turns the sidebar search field into a Stripe/Vercel/Linear-style palette: a
// floating dropdown of live results grouped by section (endpoints per tag, then
// schemas). The index is built straight from the OpenAPI document; selecting a
// result scrolls to — and expands — the matching operation/schema in the live
// Swagger UI DOM.

const METHOD_ORDER = ["get", "post", "put", "patch", "delete", "options", "head", "trace"];

// Escapes a value for safe use inside a CSS attribute selector. Spec-derived tag
// names can contain characters (" / ] etc.) that make querySelector throw a
// DOMException; falls back to the raw value only where CSS.escape is unavailable.
export function cssEscape(value) {
	return window.CSS && CSS.escape ? CSS.escape(value) : value;
}

// The global Ctrl/⌘+K shortcut is bound per document; the current handler is
// kept so it can be removed and rebound on re-init (e.g. Turbo navigation)
// instead of accumulating a new listener each time.
let shortcutHandler = null;

// Scrolls the window so the element's vertical midpoint sits at the center of
// the viewport — used after navigating so the highlighted hit lands centered
// (scrollIntoView "center" is unreliable once Swagger reflows on expand).
function centerInView(el) {
	if (!el) return;
	const rect = el.getBoundingClientRect();
	const top = window.scrollY + rect.top + rect.height / 2 - window.innerHeight / 2;
	window.scrollTo({ top: Math.max(0, top), behavior: "smooth" });
}

// Builds the grouped search index from the spec: one group per tag (endpoints),
// then a Schemas group. Group order follows spec.tags when present.
function buildIndex(spec, labels) {
	const groups = new Map();
	const groupFor = (tag) => {
		if (!groups.has(tag)) groups.set(tag, { label: tag, items: [] });
		return groups.get(tag);
	};

	(spec.tags || []).forEach((tag) => tag && tag.name && groupFor(tag.name));

	Object.entries(spec.paths || {}).forEach(([path, operations]) => {
		if (!operations) return;
		METHOD_ORDER.forEach((method) => {
			const op = operations[method];
			if (!op) return;
			const tag = (op.tags && op.tags[0]) || labels.overview;
			const summary = op.summary || op.operationId || "";
			groupFor(tag).items.push({
				type: "endpoint",
				method,
				path,
				summary,
				tag,
				haystack: `${method} ${path} ${summary} ${op.operationId || ""}`.toLowerCase(),
			});
		});
	});

	const endpointGroups = [...groups.values()].filter((group) => group.items.length);

	const schemaNames = Object.keys(spec.components?.schemas || {});
	if (schemaNames.length) {
		endpointGroups.push({
			label: labels.schemas,
			items: schemaNames.map((name) => ({ type: "schema", name, haystack: name.toLowerCase() })),
		});
	}

	return endpointGroups;
}

// Filters the index against the term. With no term it shows a capped preview per
// group so the palette is useful the moment it opens.
function filterIndex(index, term, previewPerGroup = 6) {
	if (!term) {
		return index
			.map((group) => ({ label: group.label, items: group.items.slice(0, previewPerGroup) }))
			.filter((group) => group.items.length);
	}
	return index
		.map((group) => ({ label: group.label, items: group.items.filter((item) => item.haystack.includes(term)) }))
		.filter((group) => group.items.length);
}

// Briefly rings the just-navigated element so the user sees where they landed.
function flashTarget(el) {
	if (!el) return;
	el.classList.add("ov-flash");
	window.setTimeout(() => el.classList.remove("ov-flash"), 3000);
}

// Scrolls to and expands the operation matching method + path. When the owning
// tag section is collapsed the operation isn't in the DOM (Swagger renders a
// tag's operations only while its section is open, like the Schemas section) —
// so expand the section first (and its parent group if it's a nested, hidden
// Delivery child), then poll for the operation to mount, mirroring gotoSchema.
function gotoEndpoint(root, method, path, tag) {
	if (!root) return;

	const findOp = () => {
		let op = null;
		root.querySelectorAll(`.opblock.opblock-${method} .opblock-summary-path`).forEach((summary) => {
			if (!op && summary.getAttribute("data-path") === path) op = summary.closest(".opblock");
		});
		return op;
	};

	const revealOp = (op) => {
		if (!op.classList.contains("is-open")) op.querySelector(".opblock-summary-control, .opblock-summary")?.click();
		flashTarget(op);
		// let the expand reflow settle, then center the hit in the viewport
		window.setTimeout(() => centerInView(op), 80);
	};

	// Fast path: the operation is already mounted and visible.
	const mounted = findOp();
	if (mounted && mounted.getBoundingClientRect().height > 0) {
		revealOp(mounted);
		return;
	}

	// The section that owns this path — resolved via the tag header's data-tag
	// (set by Swagger, matching the spec tag names the palette groups by).
	const tagHeader = tag ? root.querySelector(`.opblock-tag[data-tag="${cssEscape(tag)}"]`) : null;
	const section = tagHeader?.closest(".opblock-tag-section") || mounted?.closest(".opblock-tag-section");
	if (!section) {
		if (mounted) revealOp(mounted); // op exists but no section resolved (edge case)
		return;
	}

	// nested child hidden inside a collapsed Delivery group → expand the group first
	if (section.hidden && section.dataset.ovParent) {
		root.querySelector(`.opblock-tag[data-tag="${cssEscape(section.dataset.ovParent)}"][aria-expanded="false"]`)?.click();
	}
	// the tag section itself collapsed → click its native Swagger header to expand
	if (!section.classList.contains("is-open")) section.querySelector(".opblock-tag")?.click();

	let attempts = 0;
	const reveal = () => {
		const op = findOp();
		// require a real layout box, not just presence in the DOM
		if (op && op.getBoundingClientRect().height > 0) {
			revealOp(op);
			return;
		}
		if (attempts++ < 60) {
			window.setTimeout(reveal, 60);
		} else {
			// fallback: at least bring the tag section into view
			const header = section.querySelector(".opblock-tag") || section;
			flashTarget(header);
			centerInView(header);
		}
	};
	window.requestAnimationFrame(reveal);
}

// Opens the Schemas section (if collapsed), then scrolls to, flashes and expands
// the target schema. Swagger renders the schema list only while the section is
// open (closed => <noscript/>), so open it first and poll for the entry.
//
// Two renderers exist and we support both: the classic Models renderer (Swagger 2 /
// OpenAPI 3.0) tags each entry with `id="model-<name>"` + `data-name`, while
// OpenAPI 3.1 uses the JSON-Schema-2020-12 renderer, whose entries carry NO id —
// they are matched by their heading text (the document generator sets every
// schema's `title` to its component key, so the heading equals the palette name).
// The earlier code only knew the classic ids; against a 3.1 spec it never found a
// match and always fell back to flashing the whole section.
function gotoSchema(root, name) {
	if (!root) return;
	const models = root.querySelector("section.models");
	if (!models) return;

	// Resolve the target entry and its (collapsed-only) expand control, scoped to
	// the Schemas section so an inline operation schema can't be matched instead.
	const findSchema = () => {
		const classic = models.querySelector(`[id="model-${cssEscape(name)}"], .model-container[data-name="${cssEscape(name)}"]`);
		if (classic) return { el: classic, expand: classic.querySelector(".model-box-control[aria-expanded='false']") };
		for (const article of models.querySelectorAll('.json-schema-2020-12[data-json-schema-level="0"]')) {
			const heading = article.querySelector(".json-schema-2020-12-head .json-schema-2020-12__title");
			if (heading?.textContent.trim() === name) {
				// only offer the expander when collapsed — never toggle an open one shut
				const collapsed = article.querySelector(".json-schema-2020-12-accordion__icon--collapsed");
				return { el: article, expand: collapsed ? article.querySelector("button.json-schema-2020-12-accordion") : null };
			}
		}
		return null;
	};

	// Open the section if collapsed — driven off the control's aria-expanded
	// (authoritative), opened ONCE: re-clicking would toggle it shut again.
	const control = models.querySelector("button.models-control");
	if (control && control.getAttribute("aria-expanded") !== "true") control.click();

	let attempts = 0;
	const reveal = () => {
		const hit = findSchema();
		// require a real layout box, not just presence in the DOM
		if (hit && hit.el.getBoundingClientRect().height > 0) {
			hit.el.scrollIntoView({ behavior: "smooth", block: "center" });
			flashTarget(hit.el);
			// Expand the schema body AFTER the flash: expanding a large schema
			// reflows heavily, and doing it first let that steal the highlight.
			window.setTimeout(() => {
				hit.expand?.click();
				centerInView(hit.el);
			}, 150);
			return;
		}
		if (attempts++ < 100) {
			window.setTimeout(reveal, 60);
		} else {
			// fallback: bring the Schemas section into view, and surface why the
			// individual schema could not be resolved (Swagger DOM drift on upgrade).
			flashTarget(models);
			centerInView(models);
			console.warn(`[openapi] schema "${name}" not found in Schemas section`, {
				sectionOpen: models.classList.contains("is-open"),
				controlExpanded: control?.getAttribute("aria-expanded"),
				classicContainers: models.querySelectorAll(".model-container").length,
				jsonSchemaArticles: models.querySelectorAll('.json-schema-2020-12[data-json-schema-level="0"]').length,
			});
		}
	};
	window.requestAnimationFrame(reveal);
}

// Renders one palette row (an endpoint with a colored method chip, or a schema).
function renderItem(item) {
	const el = document.createElement("button");
	el.type = "button";
	el.className = "ov-palette-item";
	el.setAttribute("role", "option");

	if (item.type === "endpoint") {
		const method = document.createElement("span");
		method.className = `ov-palette-method is-${item.method}`;
		method.textContent = item.method.toUpperCase();
		const path = document.createElement("span");
		path.className = "ov-palette-path";
		path.textContent = item.path;
		el.append(method, path);
		if (item.summary) {
			const summary = document.createElement("span");
			summary.className = "ov-palette-summary";
			summary.textContent = item.summary;
			el.append(summary);
		}
	} else {
		const icon = document.createElement("i");
		icon.className = "fa fa-sitemap ov-palette-schema-icon";
		icon.setAttribute("aria-hidden", "true");
		const name = document.createElement("span");
		name.className = "ov-palette-path";
		name.textContent = item.name;
		el.append(icon, name);
	}
	return el;
}

// Wires the search input to the floating command palette: focus opens it, typing
// filters, arrows/Enter navigate the list, Ctrl/⌘+K jumps in from anywhere.
export function initCommandPalette(mount, spec, labels) {
	const input = document.getElementById("ov-nav-search");
	const palette = document.getElementById("ov-palette");
	const list = document.getElementById("ov-palette-results");
	const empty = document.getElementById("ov-palette-empty");
	const clear = document.getElementById("ov-nav-search-clear");
	const wrap = input?.closest(".ov-search");
	if (!input || !palette || !list) return;

	const index = buildIndex(spec, labels);
	const root = () => mount.querySelector(".swagger-ui");
	let flat = []; // selectable rows, in display order
	let active = -1;

	const highlight = () => {
		flat.forEach(({ el }, i) => {
			const on = i === active;
			el.classList.toggle("is-active", on);
			el.setAttribute("aria-selected", on ? "true" : "false");
		});
		const activeEl = flat[active]?.el;
		activeEl?.scrollIntoView({ block: "nearest" });
		input.setAttribute("aria-activedescendant", activeEl?.id || "");
	};

	const render = () => {
		const term = input.value.trim().toLowerCase();
		const groups = filterIndex(index, term);
		list.innerHTML = "";
		flat = [];

		groups.forEach((group) => {
			const header = document.createElement("div");
			header.className = "ov-palette-group";
			header.textContent = group.label;
			list.append(header);
			group.items.forEach((item) => {
				const el = renderItem(item);
				const entry = { item, el };
				el.id = `ov-palette-item-${flat.length}`;
				el.addEventListener("mousemove", () => {
					active = flat.indexOf(entry);
					highlight();
				});
				el.addEventListener("mousedown", (event) => {
					event.preventDefault(); // keep focus so blur-close doesn't beat the click
					select(item);
				});
				flat.push(entry);
				list.append(el);
			});
		});

		const hasResults = flat.length > 0;
		list.hidden = !hasResults;
		if (empty) empty.hidden = hasResults || !term;
		active = hasResults ? 0 : -1;
		highlight();
	};

	const open = () => {
		palette.hidden = false;
		wrap?.classList.add("is-open");
		input.setAttribute("aria-expanded", "true");
		render();
	};
	const close = () => {
		palette.hidden = true;
		wrap?.classList.remove("is-open");
		input.setAttribute("aria-expanded", "false");
		input.setAttribute("aria-activedescendant", "");
		active = -1;
	};
	const reset = () => {
		input.value = "";
		if (clear) clear.hidden = true;
		wrap?.classList.remove("has-value");
	};

	function select(item) {
		close();
		input.blur();
		if (item.type === "endpoint") gotoEndpoint(root(), item.method, item.path, item.tag);
		else gotoSchema(root(), item.name);
	}

	input.onfocus = open;
	input.oninput = () => {
		if (palette.hidden) open();
		if (clear) clear.hidden = !input.value;
		wrap?.classList.toggle("has-value", !!input.value);
		render();
	};
	// Delay close so a result click (mousedown) still registers before blur.
	input.onblur = () => window.setTimeout(close, 120);
	input.onkeydown = (event) => {
		if (event.key === "ArrowDown" && flat.length) {
			event.preventDefault();
			active = (active + 1) % flat.length;
			highlight();
		} else if (event.key === "ArrowUp" && flat.length) {
			event.preventDefault();
			active = (active - 1 + flat.length) % flat.length;
			highlight();
		} else if (event.key === "Enter" && flat[active]) {
			event.preventDefault();
			select(flat[active].item);
		} else if (event.key === "Escape") {
			event.preventDefault();
			if (input.value) {
				reset();
				render();
			} else {
				close();
				input.blur();
			}
		}
	};

	if (clear) {
		// Keep focus on mousedown so the input's blur-close timer never fires and
		// the palette doesn't close itself right after the field is re-focused.
		clear.addEventListener("mousedown", (event) => event.preventDefault());
		clear.onclick = () => {
			reset();
			input.focus();
			render();
		};
	}

	// Global Ctrl/⌘+K focuses the search from anywhere on the page. Remove any
	// previously bound handler first so re-init (Turbo nav) doesn't stack listeners.
	teardownCommandPalette();
	shortcutHandler = (event) => {
		if ((event.metaKey || event.ctrlKey) && event.key?.toLowerCase() === "k") {
			event.preventDefault();
			document.getElementById("ov-nav-search")?.focus();
		}
	};
	document.addEventListener("keydown", shortcutHandler);

	// Show ⌘ instead of Ctrl on macOS.
	if (/mac/i.test(navigator.platform || navigator.userAgent || "")) {
		const mod = wrap?.querySelector(".ov-kbd-mod");
		if (mod) mod.textContent = "⌘";
	}
}

// Removes the global Ctrl/⌘+K listener (called on re-init and SPA teardown so
// the shortcut doesn't stay active on unrelated pages).
export function teardownCommandPalette() {
	if (!shortcutHandler) return;
	document.removeEventListener("keydown", shortcutHandler);
	shortcutHandler = null;
}
