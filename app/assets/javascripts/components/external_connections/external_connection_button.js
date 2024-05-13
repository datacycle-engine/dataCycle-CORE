import CalloutHelpers from "../../helpers/callout_helpers";
import ConfirmationModal from "../confirmation_modal";

class ExternalConnectionButton {
	constructor(item) {
		this.item = item;
		this.item.classList.add("dcjs-external-connection-button");
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

		new ConfirmationModal({
			text: this.item.dataset.confirm,
			confirmationClass: this.item.dataset.confirmationButtonClass,
			cancelable: true,
			confirmationCallback: () => {
				DataCycle.httpRequest(this.item.href, {
					method: this.item.dataset.method ?? "GET",
				})
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
			},
			cancelCallback: () => {
				DataCycle.enableElement(this.item);
			},
		});
	}
}

export default ExternalConnectionButton;
