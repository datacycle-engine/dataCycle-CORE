import QuillHelpers from "../helpers/quill_helpers";

class StoredFilterForm {
	constructor(form) {
		this.form = form;
		this.form.classList.add("dcjs-stored-filter-form");
		this.idSelector = this.form.querySelector(".update-search-id-selector");
		this.formSubmit = this.form.querySelector('.buttons [type="submit"]');
		this.dynamicFormPart = this.form.querySelector(".dynamic-form-parts");
		this.searchFormPart = this.form.querySelector(".search-form-data");
		this.searchForm = document.getElementById("search-form");

		this.setup();
	}
	setup() {
		$(this.idSelector).on("change", this.reloadFormData.bind(this));

		this.form.addEventListener(
			"submit",
			this.searchFormPart && this.searchForm
				? this.injectSearchFormData.bind(this)
				: this.updateQuillEditors.bind(this),
		);
	}
	reloadFormData(_event) {
		DataCycle.disableElement(this.formSubmit, this.formSubmit.innerHTML);
		this.idSelector.disabled = true;
		this.dynamicFormPart.classList.add("dynamic-parts-loading");

		DataCycle.httpRequest("/search_history/render_update_form", {
			body: {
				stored_filter: {
					id: this.idSelector.value,
				},
			},
		})
			.then((data) => {
				this.dynamicFormPart.innerHTML = $(data.html)
					.find(".dynamic-form-parts")
					.html();
			})
			.finally(() => {
				this.idSelector.disabled = false;
				this.dynamicFormPart.classList.remove("dynamic-parts-loading");
				DataCycle.enableElement(this.formSubmit);
			});
	}
	injectSearchFormData(event) {
		event.preventDefault();
		event.stopPropagation();

		DataCycle.disableElement(this.formSubmit);

		const formData = new FormData(this.searchForm);
		this.searchFormPart.innerHTML = "";

		let formDataHtml = "";
		for (const [name, value] of Array.from(formData))
			formDataHtml += `<input type="hidden" name="${name}" value="${value}">`;

		this.searchFormPart.insertAdjacentHTML("beforeend", formDataHtml);

		this.updateQuillEditors();

		this.form.submit();
	}
	updateQuillEditors() {
		QuillHelpers.updateEditors(this.form);
	}
}

export default StoredFilterForm;
