export default class StoredFilterCacheTtl {
	static selector = ".stored-filter-cache-ttl-h";
	static className = "dcjs-stored-filter-cache-ttl";
	constructor(element) {
		this.element = element;
		this.slider = this.element
			.closest(".duration-slider")
			.querySelector(".slider");
		this.inputField = this.element
			.closest(".duration-slider-input")
			.querySelector("input[type='number']");

		this.init();
	}
	init() {
		this.inputField.addEventListener("input", this.changeHandler.bind(this));
		$(this.slider).on("moved.zf.slider", this.changeHandler.bind(this));
		this.changeHandler();
	}
	async changeHandler() {
		const value = parseInt(this.inputField.value, 10);
		let valueHours = 0;
		let valueMinutes = 0;

		if (!Number.isNaN(value) && value >= 0) {
			valueHours = Math.floor(value / 60);
			valueMinutes = value % 60;
		}

		const fullValue = [];
		if (valueHours === 24)
			fullValue.push(
				await I18n.t("data_cycle_core.stored_searches.cache_ttl.one_day"),
			);
		if (valueHours > 0 && valueHours !== 24) fullValue.push(`${valueHours}h`);
		if (valueMinutes > 0) fullValue.push(`${valueMinutes}m`);
		if (valueHours === 0 && valueMinutes === 0)
			fullValue.push(
				await I18n.t("data_cycle_core.stored_searches.cache_ttl.disabled"),
			);

		this.element.innerHTML = `= <b>${fullValue.join(" ")}</b>`;
	}
}
