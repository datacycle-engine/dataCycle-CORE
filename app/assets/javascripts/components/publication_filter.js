import DomElementHelpers from "../helpers/dom_element_helpers";
import loadingIcon from "../templates/loadingIcon";
import CalloutHelpers from "../helpers/callout_helpers";

class PublicationFilter {
	constructor(element) {
		this.element = element;
		this.element.classList.add("dcjs-publications-list");
		this.searchForm = document.getElementById("search-form");
		this.yearList = this.element.querySelector(":scope > .row > ul.accordion");
		this.loading = false;
		this.page = 1;
		this.lastPage = DomElementHelpers.parseDataAttribute(
			this.element.dataset.lastPage,
		);
		this.activeRequest;
		this.infiniteLoadingObserver = new IntersectionObserver(
			this.startInfiniteLoading.bind(this),
			{
				rootMargin: "0px 0px 50px 0px",
				threshold: 0.1,
			},
		);

		this.setup();
	}
	setup() {
		const lastElement = this.lastRenderedElement();
		if (lastElement) this.infiniteLoadingObserver.observe(lastElement);
	}
	lastRenderedElement() {
		if (!this.yearList) return;

		return Array.from(
			this.yearList.getElementsByClassName("publication-content"),
		).pop();
	}
	loadObjects() {
		this.loading = true;

		const url = this.searchForm.action;
		const method = this.searchForm.method;
		const formData = new FormData(this.searchForm);
		formData.append("infinite_scroll", true);
		formData.append("page", this.page);

		const lastYear = Array.from(
			this.yearList.getElementsByClassName("publication-year"),
		).pop()?.dataset.year;
		formData.append("last_year", lastYear);

		const lastMonth = Array.from(
			this.yearList.getElementsByClassName("publication-month"),
		).pop()?.dataset.month;
		formData.append("last_month", lastMonth);

		const lastDay = Array.from(
			this.yearList.getElementsByClassName("publication-day"),
		).pop()?.dataset.day;
		formData.append("last_day", lastDay);

		this.yearList.insertAdjacentHTML("beforeend", loadingIcon());

		const promise = DataCycle.httpRequest(url, {
			method: method,
			body: formData,
		});

		this.activeRequest = promise;

		promise
			.then(
				this.renderNewElements.bind(
					this,
					promise,
					lastYear,
					lastMonth,
					lastDay,
				),
			)
			.catch(this.renderLoadError.bind(this))
			.finally(this.disableLoading.bind(this));
	}
	disableLoading() {
		this.loading = false;
		this.element.querySelector(".loading")?.remove();
	}
	renderNewElements(promise, lastYear, lastMonth, lastDay, data) {
		if (this.activeRequest !== promise || !data?.html) return;

		this.lastPage = data.last_page;
		this.yearList.insertAdjacentHTML("beforeend", data.html);

		this.cleanupHtml(lastYear, lastMonth, lastDay);

		if (!this.lastPage)
			this.infiniteLoadingObserver.observe(this.lastRenderedElement());
	}
	cleanupHtml(lastYear, lastMonth, lastDay) {
		if (!(lastYear && lastMonth && lastDay)) return;

		this.cleanupHtmlDuplicates(`.publication-year[data-year="${lastYear}"]`);
		this.cleanupHtmlDuplicates(
			`.publication-year[data-year="${lastYear}"] .publication-month[data-month="${lastMonth}"]`,
		);
		this.cleanupHtmlDuplicates(
			`.publication-year[data-year="${lastYear}"] .publication-month[data-month="${lastMonth}"] .publication-day[data-day="${lastDay}"]`,
		);
	}
	cleanupHtmlDuplicates(selector) {
		const duplicates = Array.from(this.yearList.querySelectorAll(selector));
		const newParent = duplicates[0].querySelector(":scope > ul");

		while (duplicates.length > 1) {
			const duplicate = duplicates.pop();

			for (const child of duplicate.querySelectorAll(":scope > ul > li"))
				newParent.appendChild(child);

			duplicate.remove();
		}
	}
	renderLoadError() {
		I18n.t("frontend.load_error").then((text) =>
			CalloutHelpers.show(text, "alert"),
		);
	}
	startInfiniteLoading(entries, _observer) {
		if (this.loading || !entries.some((e) => e.isIntersecting) || this.lastPage)
			return;

		this.infiniteLoadingObserver.disconnect();

		this.page += 1;
		this.loadObjects();
	}
}

export default PublicationFilter;
