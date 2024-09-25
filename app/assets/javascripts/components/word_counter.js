import DomElementHelpers from "../helpers/dom_element_helpers";

class Counter {
	constructor(selector) {
		this.parentElem = selector;
		this.container;
		this.wrapperElem = this.parentElem.closest(".form-element");
		this.validations = DomElementHelpers.parseDataAttribute(
			this.parentElem.dataset.validations,
		);
		this.warnings = DomElementHelpers.parseDataAttribute(
			this.parentElem.dataset.warnings,
		);
		this.form = this.parentElem.closest("form");
		this.minChars;
		this.minCharsClass;
		this.maxChars;
		this.maxCharsClass;
	}
	start() {
		this.setContainer();
		const text = this.getText();
		if (text.length === 0) $(this.container).hide();
		this.setValidations();
		this.addEventHandlers();
		this.update();
	}
	setContainer() {
		if (!this.wrapperElem?.querySelector(".counter"))
			this.wrapperElem.insertAdjacentHTML(
				"beforeend",
				'<div class="counter"></div>',
			);
		this.container = this.wrapperElem.querySelector(".counter");
	}
	softValidationFor(type) {
		return this.validations?.[`soft_${type}`] || this.warnings?.[type];
	}
	validationFor(type) {
		return this.validations?.[type];
	}
	setValidations() {
		for (const type of ["max", "min"]) {
			if (this.validationFor(type)) {
				this[`${type}Chars`] = this.validationFor(type);
				this[`${type}CharsClass`] = "error";
			} else if (this.softValidationFor(type)) {
				this[`${type}Chars`] = this.softValidationFor(type);
				this[`${type}CharsClass`] = "warning";
			}
		}
	}
	addEventHandlers() {
		this.form.addEventListener("reset", this.resetCounter.bind(this));
		this.parentElem.addEventListener("input", this.update.bind(this));
	}
	resetCounter() {
		this.parentElem.value = "";
		this.update();
	}
	getText() {
		return this.parentElem.value;
	}
	countWords(text) {
		return text.trim().replace(/\n/g, "").length > 0
			? text.trim().replace(/\n/g, "").split(/\s+/).length
			: 0;
	}
	countChars(text) {
		return text.trim().replace(/\n/g, "").length > 0
			? text.trim().replace(/\n/g, "").length
			: 0;
	}
	validate(length) {
		if (this.maxChars && length > this.maxChars)
			this.container.classList.add(this.maxCharsClass);
		else if (this.minChars && length > 0 && length < this.minChars)
			this.container.classList.add(this.minCharsClass);
		else
			this.container.classList.remove(this.maxCharsClass, this.minCharsClass);
	}
	calculate() {
		const text = this.getText();
		const length = this.countChars(text);

		this.validate(length);

		return {
			words: this.countWords(text),
			chars: length,
		};
	}
	async charLabel(count) {
		return count === 1
			? await I18n.translate("frontend.word_counter.chars.one")
			: await I18n.translate("frontend.word_counter.chars.other");
	}
	async wordLabel(count) {
		return count === 1
			? await I18n.translate("frontend.word_counter.word.one")
			: await I18n.translate("frontend.word_counter.word.other");
	}
	async labelPostfix(label, count, type) {
		const maxLabel = await I18n.translate(`frontend.word_counter.${type}`, {
			label: label,
			data: count > 0 ? count : 0,
		});

		return ` ${maxLabel}`;
	}
	async minLabelPostfix(label, count) {
		const maxLabel = await I18n.translate("frontend.word_counter.min", {
			label: label,
			data: count > 0 ? count : 0,
		});

		return ` ${maxLabel}`;
	}
	async update() {
		const length = this.calculate();
		const chars = length.chars;
		const words = length.words;
		const charLabel = await this.charLabel(chars);
		const wordLabel = await this.wordLabel(words);

		if (chars === 0) $(this.container).fadeOut("fast");
		else $(this.container).fadeIn("fast");

		let counterString = `${words} ${wordLabel} / ${chars} ${charLabel}`;
		if (this.maxChars && chars > this.maxChars) {
			const rest = this.maxChars - chars;
			counterString += await this.labelPostfix(charLabel, rest, "max");
		} else if (this.minChars && chars > 0 && chars < this.minChars) {
			const rest = this.minChars - chars;
			counterString += await this.labelPostfix(charLabel, rest, "min");
		}

		this.container.textContent = counterString;
	}
}

export default Counter;
