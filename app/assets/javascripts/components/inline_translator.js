import CalloutHelpers from "../helpers/callout_helpers";

class InlineTranslator {
	constructor(item) {
		this.item = item;

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.translateText.bind(this));
	}
	getValue() {
		return this.item
			.closest(".form-element")
			.querySelector(`[name="${this.item.dataset.key}"]`).value;
	}
	getLabel() {
		return this.item.closest(".form-element").dataset.label;
	}
	async setValue(value, sourceLocale) {
		this.item
			.closest(".form-element")
			.querySelector(`[name="${this.item.dataset.key}"]`).value = value;

		CalloutHelpers.show(
			await I18n.translate("feature.translate.inline_success", {
				source_locale:
					sourceLocale &&
					(await I18n.translate(
						`locales.${sourceLocale.toLowerCase()}`,
						{},
						sourceLocale.toLowerCase(),
					)),
				target_locale: await I18n.translate(
					`locales.${this.item.dataset.locale}`,
					{},
					this.item.dataset.locale,
				),
			}),
			"success",
		);
	}
	async translateText(event) {
		event.preventDefault();

		DataCycle.disableElement(
			this.item,
			'<i class="fa fa-spinner fa-spin fa-fw"></i>',
		);

		const value = this.getValue();

		try {
			const { text, detected_source_language: detectedSourceLocale } =
				await DataCycle.httpRequest("/things/translate_text", {
					method: "POST",
					body: {
						text: typeof value === "string" ? value.trim() : value,
						target_locale: this.item.dataset.locale,
					},
				});

			this.setValue(text, detectedSourceLocale);
		} catch (error) {
			let errorMessage = await I18n.translate(
				"frontend.split_view.translate_error",
				{
					label: this.getLabel(),
				},
			);
			const responseMessage =
				error?.responseJSON?.error || error?.responseBody?.error;
			if (responseMessage) errorMessage += `<br><i>${responseMessage}</i>`;

			CalloutHelpers.show(errorMessage, "alert");
		}

		DataCycle.enableElement(this.item);
	}
}

export default InlineTranslator;
