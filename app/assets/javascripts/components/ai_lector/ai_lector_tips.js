import CalloutHelpers from "../../helpers/callout_helpers";

class AiLectorTips {
	constructor(item) {
		this.item = item;
		this.templateName = this.item.dataset.templateName;
		this.key = this.item.dataset.key;
		this.tipKey = this.item.dataset.tipKey;
		this.locale = this.item.dataset.locale;
		this.formElement = this.item.closest(".form-element");
		this.label = this.formElement.dataset.label;
		this.contentField = this.item.parentElement.querySelector(
			".ai-lector-tip-result",
		);

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.showTips.bind(this));
	}
	getValue() {
		return this.formElement.querySelector(`[name="${this.key}"]`).value;
	}
	contentFieldLoading() {
		this.contentField.innerHTML =
			'<li class="ai-lector-tip ellipsis-loading"></li>';
		this.contentField.classList.add("visible");
	}
	contentFieldValue(value) {
		this.contentField.innerHTML = value;
		this.contentField.classList.toggle("visible", !!value);
	}
	renderTips({ tips }) {
		let tipsHtml = "";
		for (const tip of tips) {
			tipsHtml += `<li class="ai-lector-tip">
        <div class="ai-lector-tip-title">${tip.title}</div>
        <div class="ai-lector-tip-content">${tip.content}</div>
      </li>`;
		}

		this.contentFieldValue(tipsHtml);
	}
	async renderError(error) {
		let errorMessage = await I18n.translate(
			"feature.ai_lector.errors.generic_error",
		);
		if (error?.responseJSON?.error)
			errorMessage += `<br><i>${error.responseJSON.error}</i>`;
		CalloutHelpers.show(errorMessage, "alert");
		this.contentField.classList.remove("visible");
	}
	async showTips(event) {
		event.preventDefault();

		DataCycle.disableElement(this.item);
		this.contentFieldLoading();

		const value = this.getValue();
		const request = DataCycle.httpRequest("/things/ai_lector/get_tips", {
			method: "POST",
			body: {
				text: typeof value === "string" ? value.trim() : value,
				target_locale: this.locale,
				template_name: this.templateName,
				key: this.key,
				tip_key: this.tipKey,
			},
		});

		request
			.then(this.renderTips.bind(this))
			.catch(this.renderError.bind(this))
			.finally(() => {
				DataCycle.enableElement(this.item);
			});
	}
}

export default AiLectorTips;
