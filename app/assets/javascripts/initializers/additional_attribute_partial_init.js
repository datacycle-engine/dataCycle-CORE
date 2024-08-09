import AdditionalAttributePartialCheckbox from "../components/additional_attribute_partial_checkbox";

export default function () {
	DataCycle.registerAddCallback(
		".dc-additional-attribute-partial",
		"additional-attribute-partial-checkbox",
		(e) => new AdditionalAttributePartialCheckbox(e),
	);
}
