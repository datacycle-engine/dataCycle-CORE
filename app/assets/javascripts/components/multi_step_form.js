import {
	randomId,
	inputFieldQuerySelector,
	getNextSibling,
	getPreviousSibling,
	parseDataAttribute,
} from "../helpers/dom_element_helpers";

export default class MultiStepForm {
	static #stepSelectors = ["fieldset", ".step"];
	static #stepLabelSelectors = ["legend", ".step-label"];
	constructor(form) {
		this.form = form;
		this.nextButton = this.form.querySelector(".next");
		this.prevButton = this.form.querySelector(".prev");
		this.resetButton = this.form.querySelector("button.reset");
		this.submitButton = this.form.querySelector("button.submit");
		this.postSubmit = this.form.querySelector("div.post-submit");
		this.crumbs = this.form.querySelector(".multi-step-crumbs");
		this.reveal = this.form.closest(".reveal");
		this.steps = this.form.querySelectorAll(this.elementSelector());
		this.init();
	}
	init() {
		if (!this.activeStep())
			this.form.querySelector(this.elementSelector()).classList.add("active");

		this.addIdsToSteps();
		this.initEventHandlers();
		this.updateForm(this.activeStep());
	}
	initEventHandlers() {
		this.nextButton.addEventListener("click", this.next.bind(this));
		this.prevButton.addEventListener("click", this.prev.bind(this));
		this.form.addEventListener("reset", this.resetForm.bind(this));
		this.form.addEventListener("keydown", this.checkForEnter.bind(this));
		this.form.addEventListener("submit", this.checkForPostSubmit.bind(this));
		$(this.reveal).on("closed.zf.reveal", this.reset.bind(this));
	}
	elementSelector() {
		return MultiStepForm.#stepSelectors.join(", ");
	}
	activeStep() {
		return this.form.querySelector(
			MultiStepForm.#stepSelectors.map((v) => `${v}.active`).join(", "),
		);
	}
	stepLabelSelector() {
		return MultiStepForm.#stepLabelSelectors.join(", ");
	}
	activeStepLabel() {
		return this.form.querySelector(
			MultiStepForm.#stepSelectors
				.flatMap((v) =>
					MultiStepForm.#stepLabelSelectors.map((l) => `${v}.active ${l}`),
				)
				.join(", "),
		);
	}
	addIdsToSteps() {
		for (const step of this.steps) {
			if (!step.id) step.id = randomId();
		}
	}
	checkForEnter(event) {
		if (event.key === "Enter") {
			event.preventDefault();
			this.next(event);
		}
	}
	checkForPostSubmit(_event) {
		if (!this.postSubmit) return;

		this.goTo(this.postSubmit.id);
	}
	async updateForm(activeElement) {
		await this.updateCrumbs(activeElement);

		if (this.form.classList.contains("disabled")) this.disableForm();
		else if (
			parseDataAttribute(this.activeStepLabel()?.dataset?.disableSubmit)
		) {
			this.enableForm();
			DataCycle.disableElement(this.submitButton);
		} else {
			this.enableForm();
			DataCycle.enableElement(this.submitButton);
		}
	}
	checkValidity(fieldset) {
		if (!fieldset.querySelector(inputFieldQuerySelector())) return true;

		const inputs = fieldset.querySelectorAll(inputFieldQuerySelector());
		for (const input of inputs) {
			if (!input.checkValidity()) {
				input.focus();
				return false;
			}
		}
		return true;
	}
	next(event) {
		event.preventDefault();
		const activeFieldset = this.activeStep();
		const nextFieldsetId = getNextSibling(activeFieldset, "fieldset")?.id;

		if (this.form.classList.contains("validation-form")) {
			activeFieldset.dispatchEvent(
				new CustomEvent("dc:form:validate", {
					detail: {
						successCallback: this.goTo.bind(this, nextFieldsetId),
					},
				}),
			);
		} else {
			if (this.checkValidity(activeFieldset)) this.goTo(nextFieldsetId);
		}
	}
	prev(event) {
		event.preventDefault();
		const activeFieldset = this.activeStep();
		const prevFieldsetId = getPreviousSibling(activeFieldset, "fieldset")?.id;

		this.goTo(prevFieldsetId, "prev");
	}
	goTo(id, action = "next") {
		const fromSet = this.activeStep();
		const toSet = document.getElementById(id);

		if (!toSet) return;
		if (fromSet === toSet) return;

		fromSet.classList.remove("active");
		this.form.dispatchEvent(
			new CustomEvent("dc:form:step", {
				detail: { fieldset: toSet, action },
			}),
		);
		toSet.classList.add("active");

		this.updateForm(toSet);
	}
	async waitForStepLabel(fieldset) {
		return await new Promise((resolve) => {
			fieldset.addEventListener(
				"dc:remote:rendered",
				() => resolve(fieldset.querySelector(this.stepLabelSelector())),
				{ once: true },
			);
		});
	}
	async stepLabel(fieldset, link = true) {
		let legend;
		if (
			fieldset.classList.contains("remote-render") ||
			fieldset.classList.contains("remote-reload")
		)
			legend = await this.waitForStepLabel(fieldset);
		else legend = fieldset.querySelector(this.stepLabelSelector());

		let text = legend?.textContent;
		if (link)
			text = `<a class="form-crumb-link" data-step-id="${fieldset.id}" data-dc-tooltip="${text}">${text}</a>`;

		return text;
	}
	async updateCrumbs(activeElement) {
		const crumbs = [];
		for (const step of this.steps) {
			if (step.classList.contains("active")) {
				crumbs.push(await this.stepLabel(step, false));
				break;
			}

			crumbs.push(
				await this.stepLabel(
					step,
					!activeElement.classList.contains("post-submit"),
				),
			);
		}

		this.crumbs.innerHTML = crumbs.join(
			" <i class='fa fa-angle-right' aria-hidden='true'></i> ",
		);
		this.initCrumbEventHandlers();
	}
	initCrumbEventHandlers() {
		for (const link of this.crumbs.querySelectorAll(".form-crumb-link")) {
			link.addEventListener("click", this.goTo.bind(this, link.dataset.stepId));
		}
	}
	disableForm() {
		DataCycle.disableElement(this.form);
		this.form.classList.add("disabled");
	}
	enableForm() {
		DataCycle.enableElement(this.form);
		this.form.classList.remove("disabled");
	}
	reset() {
		this.form.reset();
	}
	resetForm(_) {
		if (this.form.querySelector(inputFieldQuerySelector())) {
			for (const item of this.form.querySelectorAll(inputFieldQuerySelector()))
				item.blur();
		}
		this.enableForm();
		const firstFieldset = this.form.querySelector("fieldset");
		this.goTo(firstFieldset?.id);
	}
}
