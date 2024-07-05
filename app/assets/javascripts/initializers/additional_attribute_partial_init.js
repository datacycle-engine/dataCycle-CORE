import AdditionalAttributePartialCheckbox from "../components/additional_attribute_partial_checkbox";

export default function () {
	DataCycle.initNewElements(
		".dc-additional-attribute-partial:not(.dcjs-additional-attribute-partial-checkbox)",
		(e) => new AdditionalAttributePartialCheckbox(e),
	);
}
