// disable full reload of dev server (https://github.com/vitejs/vite/issues/6695#issuecomment-1069522995)
if (import.meta.hot) {
	import.meta.hot.on("vite:beforeFullReload", () => {
		throw "(skipping full reload)";
	});
}

import jQuery from "jquery";
import Rails from "@rails/ujs";
import { createConsumer } from "@rails/actioncable";
import DataCycleSingleton from "./components/data_cycle";
import I18n from "./components/i18n";

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
import "./helpers/number_helpers";
import "./helpers/string_helpers";

const initializers = import.meta.glob("./initializers/*.js", {
	eager: true,
	import: "default",
});
import foundationInit from "./initializers/foundation_init";
import validationInit from "./initializers/validation_init";
import masonryInit from "./initializers/masonry_init";
import CustomElementsInit from "./initializers/custom_elements_init";
import UrlReplacer from "./helpers/url_replacer";
import CalloutHelpers from "./helpers/callout_helpers";

const initializerExceptions = [
	"foundation_init",
	"validation_init",
	"app_signal_init",
	"masonry_init",
	"custom_elements",
];

export default (dataCycleConfig = {}, postDataCycleInit = null) => {
	DataCycle = window.DataCycle = new DataCycleSingleton(dataCycleConfig);

	UrlReplacer.cleanSearchFormParams();
	masonryInit();
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

	$(function () {
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
