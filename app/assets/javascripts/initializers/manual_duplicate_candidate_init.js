import DomElementHelpers from "../helpers/dom_element_helpers";

export default function () {
	const manualDuplicates = document.querySelector(".manual-duplicates");

	if (!manualDuplicates) return;

	const form = manualDuplicates.querySelector("form");
	const objectBrowser = manualDuplicates.querySelector(".object-browser");

	$(objectBrowser).on("dc:objectBrowser:change", (event, data) => {
		event.preventDefault();
		event.stopPropagation();

		const currentTarget = event.currentTarget;
		const formData = DomElementHelpers.getFormDataAsObject(currentTarget);

		if (formData.source_id?.length) {
			$(window).off("beforeunload");
			form.submit();
		} else console.warn("no ids given for manual duplicate_candidate");
	});
}
