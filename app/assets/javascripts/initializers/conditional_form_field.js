import ConditionalField from "../components/conditional_field";
import DisableIfAnyPresent from "../components/disable_if_any_present";

export default function () {
	DataCycle.initNewElements(
		".conditional-form-field:not(.dcjs-conditional-field)",
		(e) => new ConditionalField(e),
	);
	DataCycle.initNewElements(
		"[data-disable-if-any-present]:not(.dcjs-disable-if-any-present)",
		(e) => new DisableIfAnyPresent(e),
	);
}
