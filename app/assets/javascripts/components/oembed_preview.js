import DomElementHelpers from "../helpers/dom_element_helpers";

class OembedPreview {
	constructor(element) {
		this.element = element;
		this.oembedData = DomElementHelpers.parseDataAttribute(
			element.dataset.oembedPreview,
		);
		this.previewTargetSpinner = document.getElementById(
			`${this.element.id}_spinner`,
		);
		this.previewTarget = document.getElementById(
			`${this.element.id}_oembed_preview`,
		);

		this.init();
	}
	init() {
		this.element.addEventListener("change", this.validateOembed.bind(this));

		if (this.element.value !== "" && this.element.value !== undefined)
			this.validateOembed();
	}
	validateOembed(_event) {
		const url = this.element.value;
		this.previewTargetSpinner.classList.add("visible");
		this.previewTarget.innerHTML = "";

		DataCycle.httpRequest(`/oembed?url=${encodeURIComponent(url)}`)
			.then((response) => {
				this.previewTarget.innerHTML = response.html;
			})
			.catch((error) => {
				this.previewTarget.innerHTML = this.prettyErrors(
					error.responseBody?.errors,
				);
			})
			.finally(() => {
				this.previewTargetSpinner.classList.remove("visible");
			});
	}

	prettyErrors(errors) {
		let errorToDisplay;
		if (Array.isArray(errors) && errors.length > 0) {
			errorToDisplay = errors[errors.length - 1];
		} else if (errors.length > 0) {
			errorToDisplay = errors;
		} else {
			errorToDisplay = "";
		}

		let errorDiv = '<div class="toast-notification alert">';
		errorDiv +=
			'<i class="fa fa-exclamation-triangle" aria_hidden="true"></i> &nbsp;';
		errorDiv += `<span>${errorToDisplay}</span>`;
		errorDiv += "</div>";

		return errorDiv;
	}
}

export default OembedPreview;
