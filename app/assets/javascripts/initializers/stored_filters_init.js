import StoredFilter from "../components/stored_filter";
import StoredFilterForm from "../components/stored_filter_form";
import StoredSearchesFilter from "../components/stored_searches_filter";

export default function () {
	DataCycle.registerAddCallback(
		".stored-searches-list",
		"stored-filter",
		(e) => new StoredFilter(e),
	);
	DataCycle.registerAddCallback(
		".update-stored-search-form",
		"stored-filter-form",
		(e) => new StoredFilterForm(e),
	);

	DataCycle.registerAddCallback(
		"#search-favorites-fulltext-filter",
		"stored-searches-filter",
		(e) => new StoredSearchesFilter(e),
	);
}
