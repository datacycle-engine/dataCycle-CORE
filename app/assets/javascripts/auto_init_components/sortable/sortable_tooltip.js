export default class DcSortableTooltip {
	static selector = ".filter-sortable-checkbox-wrapper label";
	static className = "dcjs-sortable-tooltip";
	constructor(element) {
		this.label = element;
		this.checkbox = document.getElementById(this.label.getAttribute("for"));

		this.init();
	}
	init() {
		this.checkbox.addEventListener("change", this.updateTooltip.bind(this));
	}
	updateTooltip(_event) {
		if (this.checkbox.checked) {
			I18n.t("sortable.ordering.asc").then((text) => {
				this.label.dataset.dcTooltip = text;
			});
		} else {
			I18n.t("sortable.ordering.desc").then((text) => {
				this.label.dataset.dcTooltip = text;
			});
		}
	}
}
