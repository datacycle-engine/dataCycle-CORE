import DomElementHelper from "../helpers/dom_element_helpers";

class DashboardPagination {
	constructor(element) {
		this.paginationElement = element;
		this.paginationContainer = this.paginationElement.closest(
			".pagination-container",
		);
		this.form = document.getElementById("search-form");
		this.listContainer = document.querySelector("#search-results > ul");
		this.url = this.form?.action;
		this.additionalFormParams =
			DomElementHelper.parseDataAttribute(
				this.paginationElement.dataset.additionalFormParameters,
			) || {};

		this.directionNext = this.additionalFormParams.direction !== "prev";

		this.setup();
	}
	setup() {
		this.paginationElement.addEventListener("click", this.loadPage.bind(this));
	}
	loadPage(event) {
		event.preventDefault();
		event.stopPropagation();

		if (!(this.form && this.url)) return;

		DataCycle.disableElement(this.paginationElement);

		const formData = new FormData();
		for (const [key, value] of DomElementHelper.parseDataAttribute(
			this.form.dataset.initialFormData,
		) || [])
			formData.append(key, value);

		if (
			(this.listContainer.classList.contains("grid") ||
				this.listContainer.classList.contains("list")) &&
			this.listContainer.children.length > 250
		)
			this.redirectToPage(formData);
		else this.loadPageContent(formData);
	}
	loadPageContent(formData) {
		for (const [key, value] of Object.entries(this.additionalFormParams))
			formData.set(key, value);

		DataCycle.httpRequest(this.url, { method: "POST", body: formData })
			.then(this.insertNewData.bind(this, formData.get("page")))
			.catch((e) => console.warn("Could not load page:", e));
	}
	insertNewData(page, data) {
		this.paginationContainer.insertAdjacentHTML(
			this.directionNext ? "afterend" : "beforebegin",
			data.html,
		);

		this.paginationContainer.remove();

		this.pushStateToHistory(page);
	}
	pushStateToHistory(page) {
		const url = new URL(window.location);
		if (page && page >= 2) url.searchParams.set("page", page);
		else url.searchParams.delete("page");
		history.pushState({ page: page }, "", url);
	}
	redirectToPage(formData) {
		const form = document.createElement("form");
		const url = new URL(this.url);
		url.searchParams.set("page", this.additionalFormParams.page);
		form.method = "post";
		form.action = url;
		form.style.display = "none";
		form.setAttribute("accept-charset", "UTF-8");

		for (const [key, value] of formData) {
			const hiddenField = document.createElement("input");
			hiddenField.type = "hidden";
			hiddenField.name = key;
			hiddenField.value = value;

			form.append(hiddenField);
		}

		document.body.appendChild(form);
		form.submit();
	}
}

export default DashboardPagination;
