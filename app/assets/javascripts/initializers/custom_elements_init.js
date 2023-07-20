import {
	DynamicFormPart,
	ELEM_NAME as dynamicFormPartElement,
} from "../components/custom_elements/dynamic_form_part";
import CalloutHelpers from "../helpers/callout_helpers";

export default function () {
	if ("customElements" in window) {
		customElements.define(dynamicFormPartElement, DynamicFormPart);
	} else {
		I18n.t("frontend.update_browser.error").then((text) =>
			CalloutHelpers.show(text, "alert"),
		);
	}
}
