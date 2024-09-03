import CalloutHelpers from "../../helpers/callout_helpers";
import DomElementHelpers from "../../helpers/dom_element_helpers";

class AddExternalSystemButton {
	constructor(item) {
		this.item = item;
		this.link = document.querySelector(
			`[data-open="${this.item.closest(".reveal").id}"]`,
		);
		this.externalConnectionsContainer = this.link.closest(
			".external-connections",
		);

		this.setup();
	}
	setup() {
		this.item.addEventListener("submit", this.addExternalSystem.bind(this));
	}
	addExternalSystem(event) {
		event.preventDefault();
		event.stopPropagation();

		DataCycle.disableElement(this.item);

		const formData = DomElementHelpers.getFormData(this.item);

		const promise = DataCycle.httpRequest(this.item.action, {
			method: formData.get("_method") || "POST",
			body: formData,
		});

		promise
			.then((data) => {
				if (data?.html) {
					this.externalConnectionsContainer.insertAdjacentHTML(
						"afterend",
						data.html,
					);
					this.externalConnectionsContainer.remove();
				}
				if (data?.error) CalloutHelpers.show(data.error, "alert");
				if (data?.success) CalloutHelpers.show(data.success, "success");
			})
			.finally(() => {
				DataCycle.enableElement(this.item);
			});
	}
}

export default AddExternalSystemButton;
