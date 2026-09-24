// Live filter for the /schema detail page (#50201): a title search + facet chips
// that show/hide the property cards client-side. The property order is left exactly
// as the presenter delivers it (no client-side sorting). The facets and the search
// haystack are rendered onto each card by the presenter (data-schema-*), so this
// component carries no schema knowledge of its own.
export default class SchemaFilter {
	static selector = ".schema-detail";
	static className = "dcjs-schema-filter";

	constructor(element) {
		this.element = element;
		this.input = element.querySelector(".schema-filter__input");
		this.chips = Array.from(element.querySelectorAll("[data-schema-filter]"));
		this.countTarget = element.querySelector(".schema-filter__count-visible");
		this.emptyState = element.querySelector(".schema-filter__empty");

		const cards = Array.from(element.querySelectorAll(".schema-card"));
		if (!cards.length) return;

		// Precompute the haystack + facet set once so keystrokes never re-read the
		// DOM dataset; only cheap `hidden` toggles remain per filter pass.
		this.entries = cards.map((card) => ({
			card,
			haystack: card.dataset.schemaSearch || "",
			categories: (card.dataset.schemaCategories || "")
				.split(" ")
				.filter(Boolean),
		}));

		this.term = "";
		this.category = "all";

		this.init();
	}

	init() {
		this.input?.addEventListener("input", this.onSearch.bind(this));
		for (const chip of this.chips)
			chip.addEventListener("click", this.onChip.bind(this));
	}

	onSearch() {
		this.term = this.input.value.trim().toLowerCase();
		this.apply();
	}

	onChip(event) {
		const chip = event.currentTarget;
		this.category = chip.dataset.schemaFilter || "all";
		for (const other of this.chips)
			other.classList.toggle("is-active", other === chip);
		this.apply();
	}

	apply() {
		let visible = 0;
		for (const entry of this.entries) {
			const matchesCategory =
				this.category === "all" || entry.categories.includes(this.category);
			const matchesTerm = !this.term || entry.haystack.includes(this.term);
			const show = matchesCategory && matchesTerm;

			entry.card.hidden = !show;
			if (show) visible++;
		}

		if (this.countTarget) this.countTarget.textContent = visible;
		if (this.emptyState) this.emptyState.hidden = visible !== 0;
	}
}
