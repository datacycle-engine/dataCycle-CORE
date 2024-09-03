import PublicationFilter from "../components/publication_filter";

export default function () {
	DataCycle.registerAddCallback(
		".publications-list",
		"publications-list",
		(e) => new PublicationFilter(e),
	);
}
