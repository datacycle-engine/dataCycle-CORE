import StoredFilter from "../components/stored_filter";
import StoredFilterForm from "../components/stored_filter_form";
import StoredSearchesFilter from "../components/stored_searches_filter";

export default function () {
	DataCycle.initNewElements(
		".stored-searches-list:not(.dcjs-stored-filter)",
		(e) => new StoredFilter(e),
	);
	DataCycle.initNewElements(
		".update-stored-search-form:not(.dcjs-stored-filter-form)",
		(e) => new StoredFilterForm(e),
	);

	DataCycle.initNewElements(
		"#search-favorites-fulltext-filter:not(.dcjs-stored-searches-filter)",
		(e) => new StoredSearchesFilter(e),
	);
}
