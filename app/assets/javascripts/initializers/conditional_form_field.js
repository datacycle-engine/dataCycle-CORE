import ConditionalField from "../components/conditional_field";
import DisableIfAnyPresent from "../components/disable_if_any_present";
import DisableUnlessValue from "../components/disable_unless_value";

export default function () {
	DataCycle.registerAddCallback(
		".conditional-form-field",
		"conditional-field",
		(e) => new ConditionalField(e),
	);
	DataCycle.registerAddCallback(
		"[data-disable-if-any-present]",
		"disable-if-any-present",
		(e) => new DisableIfAnyPresent(e),
	);
	DataCycle.registerAddCallback(
		"[data-disable-unless-value]",
		"disable-unless-value",
		(e) => new DisableUnlessValue(e),
	);
}
