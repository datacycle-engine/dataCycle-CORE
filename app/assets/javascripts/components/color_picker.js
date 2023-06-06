import Pickr from "@simonwep/pickr";
import debounce from "lodash/debounce";

class ColorPicker {
	constructor(element) {
		this.inputField = element;
		this.container = this.inputField.closest(".ca-input");
		this.pickerField = document.createElement("div");
		this.inputField.after(this.pickerField);
		this.config = {
			el: this.pickerField,
			theme: "nano",
			position: "bottom-middle",
			comparison: false,
			default: this.inputField.value || "#333333",
			disabled: this.inputField.disabled || this.inputField.readOnly,
			swatches: [
				"rgba(244, 67, 54, 1)",
				"rgba(233, 30, 99, 1)",
				"rgba(156, 39, 176, 1)",
				"rgba(103, 58, 183, 1)",
				"rgba(63, 81, 181, 1)",
				"rgba(33, 150, 243, 1)",
				"rgba(3, 169, 244, 1)",
				"rgba(0, 188, 212, 1)",
				"rgba(0, 150, 136, 1)",
				"rgba(76, 175, 80, 1)",
				"rgba(139, 195, 74, 1)",
				"rgba(205, 220, 57, 1)",
				"rgba(255, 235, 59, 1)",
				"rgba(255, 193, 7, 1)",
			],
			components: {
				preview: true,
				opacity: true,
				hue: true,
				interaction: {
					clear: true,
				},
			},
			i18n: {
				"btn:clear": "×",
			},
		};

		this.init();
	}
	init() {
		this.pickrInstance = new Pickr(this.config);

		this.pickrInstance.on("clear", this.clearValue.bind(this));
		this.pickrInstance.on("change", this.setValue.bind(this));
		this.pickrInstance.on("swatchselect", this.setValue.bind(this));
		this.inputField.addEventListener(
			"input",
			debounce(this.updatePickrValue.bind(this), 500),
		);
		this.inputField
			.closest("form")
			.addEventListener("reset", this.resetPickrValue.bind(this));
	}
	setValue(color, _source, _instance) {
		this.inputField.value = color.toHEXA();
		this.updateNoColor();
	}
	clearValue(_instance) {
		this.inputField.value = null;
		this.updateNoColor();
	}
	updateNoColor() {
		if (this.inputField.value) this.container.classList.remove("no-color");
		else this.container.classList.add("no-color");
	}
	resetPickrValue(_event) {
		const value = this.inputField.defaultValue || null;

		this.pickrInstance.setColor(value, true);
		this.updateNoColor();
	}
	updatePickrValue(_event) {
		const value = this.inputField.value;

		if (value) this.pickrInstance.setColor(value, true);
		this.updateNoColor();
	}
}

export default ColorPicker;
