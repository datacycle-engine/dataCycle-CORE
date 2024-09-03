import DomElementHelper from "../helpers/dom_element_helpers";

class DashboardContentLink {
	constructor(element) {
		this.container = element;
		this.contentLink = this.container.querySelector("a.content-link");
		this.page = DomElementHelper.parseDataAttribute(
			this.container?.dataset.page,
		);
		this.id = this.container?.dataset.id;

		this.setup();
	}
	setup() {
		if (!this.page || !this.contentLink) return;

		this.contentLink.addEventListener("click", this.pushState.bind(this));
		this.container.addEventListener("mouseenter", this.replaceState.bind(this));
	}
	getUpdatedUrl() {
		const url = new URL(window.location);

		if (this.page >= 2) url.searchParams.set("page", this.page);
		else url.searchParams.delete("page");

		const previousState = history.state ?? {};

		return {
			url: url,
			state: Object.assign({}, previousState, { page: this.page }),
		};
	}
	replaceState(_event) {
		const { url, state } = this.getUpdatedUrl(true);

		if (url.toString() === window.location.href) return;

		history.replaceState(state, "", url);
	}
	pushState(event) {
		if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey)
			return;

		const { url, state } = this.getUpdatedUrl();

		if (this.id) {
			url.searchParams.set("thing_id", this.id);
			state.thingId = this.id;
		}

		if (url.toString() === window.location.href) return;

		history.pushState(state, "", url);
	}
}

export default DashboardContentLink;
