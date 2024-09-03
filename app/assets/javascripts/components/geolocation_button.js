import CalloutHelpers from "../helpers/callout_helpers";

class GeolocationButton {
	constructor(item) {
		this.item = item;
		this.container = this.item.closest(".advanced-filter");
		this.latitudeField = this.container.querySelector(
			'.advanced-filter-selector input[name*="lat"]',
		);
		this.longitudeField = this.container.querySelector(
			'.advanced-filter-selector input[name*="lon"]',
		);
		this.distanceField = this.container.querySelector(
			'.advanced-filter-selector input[name*="distance"]',
		);

		this.init();
	}
	init() {
		if ("geolocation" in navigator) {
			this.item.addEventListener("click", this.clickButton.bind(this));
		} else {
			this.item.style.display = "none";
		}
	}
	getPosition(options) {
		return new Promise((resolve, reject) =>
			navigator.geolocation.getCurrentPosition(resolve, reject, options),
		);
	}
	clickButton(event) {
		event.preventDefault();
		event.stopPropagation();

		this.item.classList.add("position-loading");

		this.getPosition({ timeout: 30000 })
			.then(this.setCurrentLocation.bind(this))
			.catch(this.renderError.bind(this))
			.finally(() => this.item.classList.remove("position-loading"));
	}
	setCurrentLocation(position) {
		if (this.latitudeField) {
			this.latitudeField.value = position.coords.latitude;
			this.latitudeField.dispatchEvent(new Event("change", { bubbles: true }));
		}
		if (this.longitudeField) {
			this.longitudeField.value = position.coords.longitude;
			this.longitudeField.dispatchEvent(new Event("change", { bubbles: true }));
		}
		if (this.distanceField) {
			this.distanceField.focus();
			this.distanceField.select();
		}
	}
	renderError() {
		I18n.t("common.geolocation_error").then((text) =>
			CalloutHelpers.show(text, "alert"),
		);
	}
}

export default GeolocationButton;
