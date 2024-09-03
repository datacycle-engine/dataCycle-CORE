import DomElementHelper from "../helpers/dom_element_helpers";
import ObserverHelpers from "../helpers/observer_helpers";

class ResultCount {
	constructor(element) {
		this.countContainer = element;
		this.form = document.getElementById("search-form");
		this.url = this.form?.action;
		this.additionalFormParams =
			DomElementHelper.parseDataAttribute(
				this.countContainer.dataset.additionalFormParameters,
			) || {};

		this.setup();
	}
	setup() {
		if (!(this.form && this.url)) return;

		if (this.form.classList.contains("dcjs-dashboard-filter")) this.loadCount();
		else this.waitForDashboardFilter();
	}
	waitForDashboardFilter() {
		this.waitForDashboardFilterObserver = new MutationObserver(
			this.checkFormForDashboardFilter.bind(this),
		);
		this.waitForDashboardFilterObserver.observe(
			this.form,
			ObserverHelpers.changedClassConfig,
		);
	}
	checkFormForDashboardFilter(mutations) {
		if (
			mutations.some(
				(e) =>
					e.target.classList.contains("dcjs-dashboard-filter") &&
					!e.oldValue.includes("dcjs-dashboard-filter"),
			)
		) {
			this.waitForDashboardFilterObserver.disconnect();
			this.loadCount();
		}
	}
	loadCount() {
		this.countContainer.innerHTML = "";
		this.countContainer.classList.add("loading");

		const formData = new FormData();
		for (const [key, value] of DomElementHelper.parseDataAttribute(
			this.form.dataset.initialFormData,
		) || [])
			formData.append(key, value);
		for (const [key, value] of Object.entries(this.additionalFormParams))
			formData.set(key, value);
		formData.set("count_only", true);
		if (this.form.dataset.endpointId)
			formData.set("stored_filter", this.form.dataset.endpointId);

		DataCycle.httpRequest(this.url, {
			method: "POST",
			body: formData,
		})
			.then((data) => {
				this.countContainer.insertAdjacentHTML("beforeend", data.html);
				this.countContainer.classList.remove("loading");
			})
			.catch(() => {
				console.warn("could not load count");
			});
	}
}

export default ResultCount;
