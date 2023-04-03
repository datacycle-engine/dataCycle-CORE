import JSONFormatter from "json-formatter-js";

class AdminPanel {
	constructor(element) {
		this.element = element;
		this.json = JSON.parse(this.element.dataset.json);
		this.formatter = new JSONFormatter(this.json, 3, { theme: "dark" });
		this.closeAllButton = this.element
			.closest("section.tabs-panel")
			?.querySelector(".json-formatter-close-all");
		this.openAllButton = this.element
			.closest("section.tabs-panel")
			?.querySelector(".json-formatter-open-all");

		this.init();
	}
	init() {
		this.element.replaceChildren(this.formatter.render());

		this.closeAllButton?.addEventListener("click", this.closeAll.bind(this));
		this.openAllButton?.addEventListener("click", this.openAll.bind(this));
	}
	closeAll(event) {
		event.preventDefault();
		event.stopPropagation();

		this.formatter.openAtDepth(0);
	}
	openAll(event) {
		event.preventDefault();
		event.stopPropagation();

		this.formatter.openAtDepth(Infinity);
	}
}

export default AdminPanel;
