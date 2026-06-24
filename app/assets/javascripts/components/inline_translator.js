import CalloutHelpers from "../helpers/callout_helpers";
import { translateText } from "../helpers/translate_feature_helpers";

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

		const translatedValue = await translateText(
			this.getLabel(),
			this.getValue(),
			this.item.dataset.locale,
		);

		if (translatedValue?.text) {
			this.setValue(
				translatedValue.text,
				translatedValue.detected_source_language,
			);
		}

		DataCycle.enableElement(this.item);
	}
}

export default InlineTranslator;
