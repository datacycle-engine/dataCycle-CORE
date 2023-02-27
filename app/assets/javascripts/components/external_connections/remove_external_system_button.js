import CalloutHelpers from "../../helpers/callout_helpers";
import ConfirmationModal from "../confirmation_modal";

class RemoveExternalSystemButton {
	constructor(item) {
		this.item = item;
		this.item.classList.add("dcjs-remove-external-system-button");
		this.externalConnectionsContainer = this.item.closest(
			".external-connections",
		);

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.removeExternalSystem.bind(this));
	}
	removeExternalSystem(event) {
		event.preventDefault();
		event.stopPropagation();

		DataCycle.disableElement(this.item);

		new ConfirmationModal({
			text: this.item.dataset.confirm,
			confirmationClass: "alert",
			cancelable: true,
			confirmationCallback: () => {
				DataCycle.httpRequest(this.item.href, { method: "DELETE" })
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
					.catch(() => {
						DataCycle.enableElement(this.item);
					});
			},
			cancelCallback: () => {
				DataCycle.enableElement(this.item);
			},
		});
	}
}

export default RemoveExternalSystemButton;
