const customElementComponents = import.meta.glob("./custom_elements/**/*.js", {
	eager: true,
	import: "default",
});

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
	I18n.t("frontend.update_browser.error").then((text) =>
		CalloutHelpers.show(text, "alert"),
	);
}
