import QuillHelpers from "../../helpers/quill_helpers";
import DomElementHelpers from "../../helpers/dom_element_helpers";

class ClassificationEditForm {
	constructor(item) {
		this.item = item;
		this.item.classList.add("dcjs-classification-edit-form");
		this.liElement = this.item.closest("li");
		this.container = document.getElementById("classification-administration");
		this.submitButton = this.item.querySelector(".submit-button");

		this.setup();
	}
	setup() {
		this.item.addEventListener("submit", this.submitForm.bind(this));
		this.item.addEventListener("reset", this.resetForm.bind(this));
		for (const link of this.item.querySelectorAll(".ca-translation-link"))
			link.addEventListener("click", this.changeLocale.bind(this));
	}
	changeLocale(event) {
		event.preventDefault();
		event.stopPropagation();

		const currentTarget = event.currentTarget;
		const locale = currentTarget.dataset.locale;

		this.item.querySelector(".list-items a.active").classList.remove("active");
		this.item
			.querySelector(`.list-items [data-locale="${locale}"]`)
			.classList.add("active");
		for (const input of this.item.querySelectorAll(".ca-input > .active"))
			input.classList.remove("active");
		for (const input of this.item.querySelectorAll(`.ca-input > .${locale}`))
			input.classList.add("active");
	}
	resetForm(_event) {
		this.liElement.classList.remove("active");
	}
	isParentClassificationAlias(elem) {
		return elem.nodeName === "LI" && elem.hasAttribute("data-id");
	}
	reloadOnNextOpen(elem) {
		if (elem.nodeName !== "LI") return;

		elem
			.querySelector(":scope > .inner-item > .name")
			.classList.remove("open", "loaded");
		elem.querySelector(":scope > ul.children").classList.remove("open");
	}
	hideAncestors() {
		const oldTop = this.liElement.getBoundingClientRect().top;
		const isNew = !this.liElement.dataset.id;
		const id =
			this.liElement.dataset.id ||
			this.liElement.parentElement.parentElement.dataset.id;

		for (const elem of document.querySelectorAll(`li[data-id="${id}"]`)) {
			if (elem.id) continue;

			this.reloadOnNextOpen(elem);
			if (!isNew) this.reloadOnNextOpen(elem.parentElement.parentElement);
		}

		window.scrollTo({
			top:
				window.scrollY - (oldTop - this.liElement.getBoundingClientRect().top),
		});
	}
	submitForm(event) {
		event.preventDefault();
		event.stopPropagation();

		DataCycle.disableElement(this.item);
		QuillHelpers.updateEditors(this.item);

		const formData = DomElementHelpers.getFormData(this.item);

		const promise = DataCycle.httpRequest(this.item.action, {
			method: formData.get("_method") || "POST",
			body: formData,
		});

		promise
			.then((data) => {
				if (data?.html)
					this.liElement.insertAdjacentHTML("beforebegin", data.html);

				this.hideAncestors();

				this.liElement.remove();

				for (const li of this.container.querySelectorAll("li.active"))
					li.classList.remove("active");
			})
			.finally(() => {
				DataCycle.enableElement(this.item);
			});
	}
}

export default ClassificationEditForm;
