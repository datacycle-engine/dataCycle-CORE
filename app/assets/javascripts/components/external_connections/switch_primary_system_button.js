import CalloutHelpers from "./../../helpers/callout_helpers";

class SwitchPrimarySystemButton {
	constructor(item) {
		this.item = item;
		this.item.classList.add("dcjs-switch-primary-system-button");
		this.externalConnectionsContainer = this.item.closest(
			".external-connections",
		);

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.switchPrimarySystem.bind(this));
	}
	switchPrimarySystem(event) {
		event.preventDefault();
		event.stopPropagation();

		DataCycle.disableElement(this.item);

		DataCycle.httpRequest(this.item.href, { method: "POST" })
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

export default SwitchPrimarySystemButton;
