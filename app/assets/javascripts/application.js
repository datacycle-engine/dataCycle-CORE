// disable full reload of dev server (https://github.com/vitejs/vite/issues/6695#issuecomment-1069522995)
if (import.meta.hot) {
	import.meta.hot.on("vite:beforeFullReload", () => {
		throw "(skipping full reload)";
	});
}

import { cable, Turbo } from "@hotwired/turbo-rails";
import Rails from "@rails/ujs";
import jQuery from "jquery";
import autoInitComponents from "./auto_init_components";
import DataCycleSingleton from "./components/data_cycle";
import I18n from "./components/i18n";
import initCustomElements from "./custom_elements";
import initGlobalComponents from "./global_components";
import initialize from "./initializers";

Object.assign(window, {
	$: jQuery,
	jQuery,
	Rails,
	I18n,
	actionCable: cable.createConsumer(),
});

import { turboConfirmMethod } from "./initializers/rails_confirmation_init";

Turbo.session.drive = false;
Turbo.config.forms.confirm = turboConfirmMethod;

import "jquery-serializejson";
import "lazysizes";
import "lazysizes/plugins/unveilhooks/ls.unveilhooks.js";
import CalloutHelpers from "./helpers/callout_helpers";
import "./helpers/number_helpers";
import "./helpers/string_helpers";
import UrlReplacer from "./helpers/url_replacer";
import foundationInit from "./initializers/foundation_init";
import validationInit from "./initializers/validation_init";

export default (dataCycleConfig = {}, postDataCycleInit = null) => {
	DataCycle = window.DataCycle = new DataCycleSingleton(dataCycleConfig);

	initCustomElements();
	UrlReplacer.cleanSearchFormParams();

	try {
		Rails.start();
	} catch {}

	initGlobalComponents();
	autoInitComponents();

	if (typeof postDataCycleInit === "function") postDataCycleInit();

	DataCycle.notifications.addEventListener("error", ({ detail }) => {
		if (detail.message?.includes("not a valid selector"))
			I18n.t("frontend.update_browser").then((text) =>
				CalloutHelpers.show(text, "alert"),
			);

		console.error(detail);
	});

	$(() => {
		initialize();
		foundationInit();
		validationInit();
	});
};
