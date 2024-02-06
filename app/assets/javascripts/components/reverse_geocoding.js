import ConfirmationModal from "./confirmation_modal";
import DomElementHelpers from "../helpers/dom_element_helpers";

class ReverseGeocoding {
	constructor(element) {
		element.classList.add("dcjs-reverse-geocoding");
		this.element = element;
		this.sourceKey = this.element.dataset.sourceKey;
		this.sourceElement = document.querySelector(
			`input[type="hidden"][name$="[${this.sourceKey}]"]`,
		);
		this.addressContainer = this.element.closest(".form-element");
		this.locale = this.element.dataset.locale;

		this.setup();
	}
	setup() {
		this.element.addEventListener(
			"click",
			this.triggerReverseGeocode.bind(this),
		);
	}
	triggerReverseGeocode(event) {
		event.preventDefault();
		event.stopPropagation();

		if (this.element.classList.contains("disabled")) return;

		this.reverseGeocode();
	}
	reverseGeocode() {
		if (!this.sourceElement) return;

		const geo = DomElementHelpers.parseDataAttribute(this.sourceElement.value);

		DataCycle.disableElement(this.element);

		const promise = DataCycle.httpRequest("/things/reverse_geocode_address", {
			body: { geo: geo },
		});

		promise
			.then((data) => {
				if (data.error) {
					new ConfirmationModal({
						text: data.error,
					});
				} else if (data) {
					this.setGeocodedValue(data);
				}
			})
			.catch((_jqxhr, textStatus, error) => {
				console.error(`${textStatus}, ${error}`);
			})
			.finally(() => {
				DataCycle.enableElement(this.element);
			});

		return promise;
	}
	setGeocodedValue(data) {
		for (const [key, value] of Object.entries(data)) {
			const formElement = this.addressContainer.querySelector(
				DataCycle.config.EditorSelectors.map(
					(v) => `.form-element[data-key$="[${key}]"] ${v}`,
				).join(", "),
			);

			$(formElement).trigger("dc:import:data", {
				value: value,
				locale: this.locale,
			});
		}
	}
}

export default ReverseGeocoding;
