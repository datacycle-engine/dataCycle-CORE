import PublicationFilter from "../components/publication_filter";

export default function () {
	DataCycle.initNewElements(
		".publications-list:not(.dcjs-publications-list)",
		(e) => new PublicationFilter(e),
	);
}
