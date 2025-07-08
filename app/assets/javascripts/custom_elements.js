const customElementComponents = import.meta.glob("./custom_elements/**/*.js", {
	eager: true,
	import: "default",
});

import { showCallout } from "./helpers/callout_helpers";

export default function () {
	if ("customElements" in window) {
		for (const path in customElementComponents) {
			try {
				const component = customElementComponents[path];
				customElements.define(
					component.registeredName,
					component,
					component.options,
				);
			} catch (err) {
				DataCycle.notifications.dispatchEvent(
					new CustomEvent("error", { detail: err }),
				);
			}
		}
	} else {
		I18n.t("frontend.update_browser").then((text) =>
			showCallout(text, "alert"),
		);
	}
}
