import CalloutHelpers from "../../helpers/callout_helpers";
import QuillHelpers from "../../helpers/quill_helpers";
import { nanoid } from "nanoid";

class AiLectorTips {
	constructor(item) {
		this.item = item;
		this.templateName = this.item.dataset.templateName;
		this.key = this.item.dataset.key;
		this.tipKey = this.item.dataset.tipKey;
		this.locale = this.item.dataset.locale;
		this.formElement = this.item.closest(".form-element");
		this.label = this.formElement.dataset.label;
		this.contentField =
			this.item.parentElement.querySelector(".ai-lector-result");
		this.identifier = nanoid();
		this.streaming = false;
		this.aiLectorContainer = this.item.closest(".ai-lector-dropdown");
		this.valueField = this.formElement.querySelector(`[name="${this.key}"]`);
		this.timeout;

		this.setup();
	}
	setup() {
		this.item.id = this.identifier;
		this.item.addEventListener("click", this.showTips.bind(this));
		this.item.addEventListener("data", this.renderResult.bind(this));
		this.item.addEventListener("reset", this.reset.bind(this));
	}
	getValue() {
		if (this.valueField.type === "hidden")
			QuillHelpers.updateEditors(this.formElement);
		return this.valueField.value;
	}
	contentFieldLoading() {
		this.clearNeighboringTips();
		this.streaming = true;
		DataCycle.disableElement(this.item);
		this.contentField.textContent = "";
		this.contentField.classList.add("visible", "ellipsis-loading");
	}
	clearNeighboringTips() {
		const neighboringTips = this.aiLectorContainer.querySelectorAll(
			":scope > ul > li > button",
		);
		for (const tip of neighboringTips) {
			if (tip !== this.item) tip.dispatchEvent(new Event("reset"));
		}
	}
	contentFieldFinished() {
		this.streaming = false;
		if (this.timeout) clearTimeout(this.timeout);
		DataCycle.enableElement(this.item);
	}
	reset() {
		this.contentFieldFinished();
		this.contentField.textContent = "";
		this.contentField.classList.remove("visible", "ellipsis-loading");
	}
	async renderError(error, cssClass = "alert", key = "errors") {
		let message = error;
		if (!message)
			message = await I18n.translate(`feature.ai_lector.${key}.generic`);
		CalloutHelpers.show(message, cssClass);
		this.contentField.classList.remove("visible");
		this.reset();
	}
	async showTips(event) {
		event.preventDefault();

		this.contentFieldLoading();

		try {
			DataCycle.globals.aiLector.send({
				text: this.getValue(),
				locale: this.locale,
				template_name: this.templateName,
				key: this.key,
				tip_key: this.tipKey,
				identifier: this.identifier,
			});
		} catch (error) {
			I18n.t("feature.ai_lector.warnings.no_connection").then((text) =>
				CalloutHelpers.show(text, "info"),
			);
			this.reset();
		}
	}
	renderResult(event) {
		event.preventDefault();

		const data = event.detail;

		if (data?.error) this.renderError(data.error);
		else if (data?.warning) this.renderError(data.warning, "info", "warnings");
		else if (data?.data) this.appendData(data.data);

		if (data?.finished) this.contentFieldFinished();
	}
	appendData(data) {
		if (this.streaming) {
			if (this.timeout) clearTimeout(this.timeout);
			this.timeout = setTimeout(this.contentFieldFinished.bind(this), 30000);
			this.contentField.classList.remove("ellipsis-loading");
			this.contentField.textContent += data;
		}
	}
}

export default AiLectorTips;
