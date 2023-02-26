import DomElementHelpers from "../../helpers/dom_element_helpers";
import CalloutHelpers from "../../helpers/callout_helpers";

class LoadMoreLinkedButton {
	constructor(item) {
		this.item = item;
		this.parent = this.item.parentElement.classList.contains("clear-both")
			? this.item.parentElement
			: this.item;
		this.objectListElement = this.item.closest(
			".object-thumbs, .embedded-object, .content-tiles, .embedded-viewer",
		);
		this.options = {};

		this.setup();
	}
	setup() {
		for (const [key, value] of Object.entries(this.item.dataset))
			this.options[key] = DomElementHelpers.parseDataAttribute(value);

		this.item.addEventListener("click", this.loadMoreLinked.bind(this));
	}
	loadMoreLinked(event) {
		event.preventDefault();
		event.stopPropagation();

		DataCycle.disableElement(this.item);

		DataCycle.httpRequest(this.item.href, {
			method: "POST",
			body: this.options,
		})
			.then(this.renderLoadedItems.bind(this))
			.catch(this.renderLoadError.bind(this));
	}
	hiddenIdSelector(id) {
		return `:scope > input[type="hidden"][value="${id}"], :scope > .content-object-item.hidden[data-id="${id}"]`;
	}
	renderLoadedItems(data) {
		if (!(data?.html && data?.ids)) return;

		const ids = data.ids;
		const idSelector = ids.map(this.hiddenIdSelector.bind(this)).join(", ");
		const lastHiddenItem = this.objectListElement.querySelector(
			this.hiddenIdSelector(ids[ids.length - 1]),
		);

		if (lastHiddenItem) {
			lastHiddenItem.insertAdjacentHTML("afterend", data.html);
			for (const elem of this.objectListElement.querySelectorAll(idSelector))
				elem.remove();
		} else this.objectListElement.insertAdjacentHTML("beforeend", data.html);

		this.parent.remove();
	}
	renderLoadError() {
		DataCycle.enableElement(this.item);

		I18n.t("frontend.load_error").then((text) =>
			CalloutHelpers.show(text, "alert"),
		);
	}
}

export default LoadMoreLinkedButton;
