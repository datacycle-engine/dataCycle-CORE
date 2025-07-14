export default class DynamicFormPart extends HTMLElement {
	constructor() {
		super();

		this.events = {
			change: this.reloadDynamicParts.bind(this),
		};
	}
	static registeredName = "dynamic-form-part";
	connectedCallback() {
		this.formElement = this.closest("form");
		const identifierSelectId = this.getAttribute("dependent-on");
		this.identifierSelect = document.getElementById(identifierSelectId);

		for (const [event, callback] of Object.entries(this.events))
			this.identifierSelect.addEventListener(event, callback);
	}
	disconnectedCallback() {
		this.formElement = undefined;

		for (const [event, callback] of Object.entries(this.events))
			this.identifierSelect.removeEventListener(event, callback);
	}
	reloadDynamicParts(_event) {
		const formSubmits = this.formElement.querySelectorAll('[type="submit"]');

		if (!this.identifierSelect) return;

		for (const submit of formSubmits) DataCycle.disableElement(submit);
		this.identifierSelect.disabled = true;
		this.classList.add("dynamic-part-loading");

		const body = {};
		body[this.identifierSelect.name] = this.identifierSelect.value;

		DataCycle.httpRequest(this.getAttribute("url"), {
			body: body,
		})
			.then((data) => {
				this.innerHTML = data?.html ?? "";
			})
			.finally(() => {
				this.classList.remove("dynamic-part-loading");
				this.identifierSelect.disabled = false;
				for (const submit of formSubmits) DataCycle.enableElement(submit);
			});
	}
}
