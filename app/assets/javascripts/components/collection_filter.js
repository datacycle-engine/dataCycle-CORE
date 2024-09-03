import debounce from "lodash/debounce";

class CollectionFilter {
	constructor(selector) {
		this.selector = $(selector);
		this.filterInput = this.selector.find(
			".watch-lists-filter .watch-list-filter-param",
		);
		this.filterResetButton = this.selector.find(
			".watch-lists-filter .reset-watch-list-filter",
		);
		this.collection = this.selector.find(".list-items");
		this.newForm = this.selector.find(".add-watchlist .add-watchlist-form");
		this.filterInputTimeout = null;

		this.init();
	}
	init() {
		this.filterInput.on(
			"input",
			debounce(this.filterCollection.bind(this), 500),
		);
		this.filterResetButton.on("click", this.resetFilter.bind(this));
		this.selector.on(
			"dc:collection:filter",
			this.setFilterInputValue.bind(this),
		);
		this.newForm.on(
			"dc:collection:newCollection",
			this.addNewCollection.bind(this),
		);
	}
	resetFilter(event) {
		event.preventDefault();

		this.filterInput.val(null);
		this.syncFilterInputs(null);
		this.filterCollection();
	}
	filterCollection() {
		DataCycle.disableElement(this.filterResetButton);
		const q = (this.filterInput.val() || "").trim().toLowerCase();

		this.toggleResetButton(q.length > 0);
		this.collection.trigger("dc:remote:reload", { options: { q: q } });

		DataCycle.enableElement(this.filterResetButton);
		this.syncFilterInputs(q);
	}
	syncFilterInputs(q) {
		$(".dropdown-pane.watch-lists")
			.not(this.selector)
			.trigger("dc:collection:filter", { q: q });
	}
	toggleResetButton(show) {
		if (show) this.filterResetButton.fadeIn(100);
		else this.filterResetButton.fadeOut(100);
	}
	setFilterInputValue(event, data) {
		event.stopPropagation();

		const filterValue = (data && data.q) || "";
		this.filterInput.val(filterValue);

		this.toggleResetButton(filterValue.length > 0);

		this.collection.trigger("dc:remote:reloadOnNextOpen", { q: filterValue });
	}
	addNewCollection(_event) {
		this.newForm.find(":text").val(null);
		this.filterCollection();
		$(".dropdown-pane.watch-lists .list-items")
			.not(this.collection)
			.trigger("dc:remote:reloadOnNextOpen");
	}
}

export default CollectionFilter;
