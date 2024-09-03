import DataLinkForm from "../components/data_link_form";

export default function () {
	DataCycle.registerAddCallback(
		".data-link-form",
		"data-link-form",
		(e) => new DataLinkForm(e),
	);
}
