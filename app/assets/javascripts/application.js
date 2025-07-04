// disable full reload of dev server (https://github.com/vitejs/vite/issues/6695#issuecomment-1069522995)
if (import.meta.hot) {
	import.meta.hot.on("vite:beforeFullReload", () => {
		throw "(skipping full reload)";
	});
}

import "@hotwired/turbo-rails";
import { createConsumer } from "@rails/actioncable";
import Rails from "@rails/ujs";
import jQuery from "jquery";
import DataCycleSingleton from "./components/data_cycle";
import I18n from "./components/i18n";

Turbo.session.drive = false;

Object.assign(window, {
	$: jQuery,
	jQuery,
	Rails,
	actionCable: createConsumer(),
	I18n,
});

import "jquery-serializejson";
import "lazysizes";
import "lazysizes/plugins/unveilhooks/ls.unveilhooks.js";
import CalloutHelpers from "./helpers/callout_helpers";
import "./helpers/number_helpers";
import "./helpers/string_helpers";
import UrlReplacer from "./helpers/url_replacer";
import CustomElementsInit from "./initializers/custom_elements_init";
import foundationInit from "./initializers/foundation_init";
import validationInit from "./initializers/validation_init";

const initializers = import.meta.glob("./initializers/*.js", {
	eager: true,
	import: "default",
});
const autoInitComponents = import.meta.glob("./auto_init_components/*.js", {
	eager: true,
	import: "default",
});

const initializerExceptions = [
	"foundation_init",
	"validation_init",
	"app_signal_init",
	"custom_elements",
];

export default (dataCycleConfig = {}, postDataCycleInit = null) => {
	DataCycle = window.DataCycle = new DataCycleSingleton(dataCycleConfig);

	UrlReplacer.cleanSearchFormParams();
	CustomElementsInit();

	try {
		Rails.start();
	} catch {}

	if (typeof postDataCycleInit === "function") postDataCycleInit();
	DataCycle.notifications.addEventListener("error", ({ detail }) => {
		if (detail.message?.includes("not a valid selector"))
			I18n.t("frontend.update_browser").then((text) =>
				CalloutHelpers.show(text, "alert"),
			);

		console.error(detail);
	});

	$(() => {
		for (const path in autoInitComponents) {
			try {
				const component = autoInitComponents[path];
				const initFunction = component.lazy
					? "registerLazyAddCallback"
					: "registerAddCallback";

				DataCycle[initFunction](
					component.selector,
					component.className,
					(e) => new component(e),
				);
			} catch (err) {
				DataCycle.notifications.dispatchEvent(
					new CustomEvent("error", { detail: err }),
				);
			}
		}

		for (const path in initializers) {
			if (!initializerExceptions.some((e) => path.includes(e))) {
				try {
					initializers[path]();
				} catch (err) {
					DataCycle.notifications.dispatchEvent(
						new CustomEvent("error", { detail: err }),
					);
				}
			}
		}
		foundationInit();
		validationInit();
	});
};
