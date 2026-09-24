// Search, sort, schema-part tabs and the "only with contents" toggle for the /schema
// overview (#50192). Sibling of SchemaFilter, which does the narrower job on the detail
// page — different pages, and the overview also sorts, counts per group and drives a
// tablist, so the two share the approach rather than the code.
//
// The presenter renders the haystack, the schema part and the sort values onto each card
// as data-* attributes, so this carries no schema knowledge of its own.

// The dropdown's options, each naming a precomputed entry field (see the constructor) plus
// a direction. Heading and type sort alphabetically, the content count numerically.
export const SORTS = {
	heading_asc: { key: "sortName", numeric: false, desc: false },
	heading_desc: { key: "sortName", numeric: false, desc: true },
	type_asc: { key: "sortPath", numeric: false, desc: false },
	type_desc: { key: "sortPath", numeric: false, desc: true },
	count_desc: { key: "count", numeric: true, desc: true },
	count_asc: { key: "count", numeric: true, desc: false },
};

export const DEFAULT_SORT = "heading_asc";

// Compares two cards' precomputed sort values under one spec. localeCompare's
// `sensitivity` and `numeric` options are what keep umlauts with their base letter and
// "Bild 10" after "Bild 9"; a missing count counts as 0. Each of those is pinned in
// test/javascript/schema_index_filter_test.mjs.
//
// @param spec [Object] one SORTS entry
// @return [Number] negative, zero or positive, as Array#sort expects
export function compareValues(a, b, spec) {
	const cmp = spec.numeric
		? (Number.parseFloat(a) || 0) - (Number.parseFloat(b) || 0)
		: String(a).localeCompare(String(b), undefined, {
				sensitivity: "base",
				numeric: true,
			});

	return spec.desc ? -cmp : cmp;
}

// Whether one card survives the three independent filters: the search term, the selected
// schema part, and the "only with contents" toggle.
export function matchesFilters(entry, { term, part, onlyWithContent }) {
	if (term && !entry.haystack.includes(term)) return false;
	if (entry.part !== part) return false;

	return !onlyWithContent || entry.count > 0;
}

export default class SchemaIndexFilter {
	static selector = "[data-schema-index]";
	static className = "dcjs-schema-index-filter";

	constructor(element) {
		this.element = element;
		this.input = element.querySelector("[data-schema-search]");
		this.empty = element.querySelector("[data-schema-empty]");
		this.parts = Array.from(element.querySelectorAll("[data-schema-part]"));
		this.withContentToggle = element.querySelector(
			"[data-schema-with-content]",
		);
		this.sortSelect = element.querySelector("[data-schema-sort]");
		this.expandAll = element.querySelector("[data-schema-expand-all]");

		// Which schema is shown — "main" (entity + container) or "embedded". The main
		// schema is the default, so embedded contents never appear under Hauptschema.
		this.part = "main";
		this.term = "";
		// Independent of the search and the part: when on, only templates with a
		// content count > 0 show.
		this.onlyWithContent = false;
		this.allOpen = false;

		// Precompute per group so a keystroke never re-reads the DOM dataset; only the
		// `hidden` toggles and the count badge remain per pass.
		this.groups = Array.from(
			element.querySelectorAll("[data-schema-group]"),
		).map((group) => ({
			group,
			grid: group.querySelector(".schema-group__grid"),
			countTarget: group.querySelector("[data-schema-group-count]"),
			entries: Array.from(group.querySelectorAll("[data-schema-card]")).map(
				(card) => ({
					card,
					haystack: (card.dataset.search || "").toLowerCase(),
					part: card.dataset.part,
					count: Number.parseFloat(card.dataset.sortCount) || 0,
					sortName: card.dataset.sortName || "",
					sortPath: card.dataset.sortPath || "",
				}),
			),
		}));

		this.init();
	}

	init() {
		this.input?.addEventListener("input", this.onSearch.bind(this));
		this.sortSelect?.addEventListener("change", this.sort.bind(this));
		this.withContentToggle?.addEventListener(
			"click",
			this.onWithContent.bind(this),
		);
		this.expandAll?.addEventListener("click", this.onExpandAll.bind(this));

		this.parts.forEach((part, index) => {
			part.addEventListener("click", () => this.selectPart(part));
			part.addEventListener("keydown", (event) => this.onPartKey(event, index));
		});

		// A click on a schema's link inside a <summary> must navigate without also
		// toggling its parent <details>.
		for (const link of this.element.querySelectorAll("summary a"))
			link.addEventListener("click", (event) => event.stopPropagation());

		this.sort();
		this.apply();
	}

	onSearch() {
		this.term = this.input.value.trim().toLowerCase();
		this.apply();
	}

	onWithContent() {
		this.onlyWithContent = !this.onlyWithContent;
		this.withContentToggle.classList.toggle("is-active", this.onlyWithContent);
		this.withContentToggle.setAttribute(
			"aria-pressed",
			this.onlyWithContent ? "true" : "false",
		);
		this.apply();
	}

	// Arrow keys move between the tabs, matching the roving tabindex set in #selectPart —
	// a screen reader user should not have to guess that the buttons exclude each other.
	onPartKey(event, index) {
		const step =
			event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
		if (!step) return;

		event.preventDefault();
		const next =
			this.parts[(index + step + this.parts.length) % this.parts.length];
		this.selectPart(next);
		next.focus();
	}

	selectPart(part) {
		this.part = part.dataset.schemaPart;
		for (const other of this.parts) {
			const on = other === part;
			other.classList.toggle("is-active", on);
			other.setAttribute("aria-selected", on ? "true" : "false");
			other.setAttribute("tabindex", on ? "0" : "-1");
		}

		// Two tabs share the grid panel, so the panel is labelled by whichever of them
		// is currently selected.
		const panel = document.getElementById(part.getAttribute("aria-controls"));
		panel?.setAttribute("aria-labelledby", part.id);

		this.setView();
	}

	// The "Abhängigkeiten" tab swaps the card grid for the dependency tree; the card-only
	// controls (search, content toggle, sort) are hidden through the `is-deps` state class
	// (see the stylesheet). Grid views re-run the filter.
	setView() {
		const depsView = this.part === "deps";
		this.element.classList.toggle("is-deps", depsView);
		if (!depsView) this.apply();
	}

	// Reorders the cards inside each schema.org-type group. The groups keep their own
	// order, and filtering only toggles `hidden`, so the sort survives every search or
	// tab change without re-sorting.
	sort() {
		const spec = SORTS[this.sortSelect?.value] || SORTS[DEFAULT_SORT];

		for (const { grid, entries } of this.groups) {
			if (!grid) continue;

			const fragment = document.createDocumentFragment();
			for (const entry of [...entries].sort((a, b) =>
				compareValues(a[spec.key], b[spec.key], spec),
			))
				fragment.appendChild(entry.card);

			grid.appendChild(fragment);
		}
	}

	// A group hides when none of its cards match, and its badge shows how many are
	// currently visible.
	apply() {
		const filters = {
			term: this.term,
			part: this.part,
			onlyWithContent: this.onlyWithContent,
		};
		let anyVisible = false;

		for (const { group, countTarget, entries } of this.groups) {
			let groupVisible = 0;

			for (const entry of entries) {
				const visible = matchesFilters(entry, filters);
				entry.card.hidden = !visible;
				if (visible) groupVisible++;
			}

			group.hidden = groupVisible === 0;
			if (countTarget) countTarget.textContent = groupVisible;
			if (groupVisible > 0) anyVisible = true;
		}

		if (this.empty) this.empty.hidden = anyVisible;
	}

	onExpandAll() {
		this.allOpen = !this.allOpen;
		for (const details of this.element.querySelectorAll("[data-schema-dep]"))
			details.open = this.allOpen;

		this.expandAll.classList.toggle("is-active", this.allOpen);
		this.expandAll.setAttribute(
			"aria-pressed",
			this.allOpen ? "true" : "false",
		);

		const label = this.expandAll.querySelector("[data-schema-expand-label]");
		if (label)
			label.textContent = this.expandAll.getAttribute(
				this.allOpen ? "data-label-collapse" : "data-label-expand",
			);
	}
}
