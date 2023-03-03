import ConfirmationModal from "../confirmation_modal";

class ClassificationDestroyButton {
	constructor(item) {
		this.item = item;
		this.item.classList.add("dcjs-classification-destroy-button");

		this.setup();
	}
	setup() {
		this.item.addEventListener("click", this.destroy.bind(this));
	}
	destroy(event) {
		event.preventDefault();
		event.stopPropagation();

		DataCycle.disableElement(this.item);

		new ConfirmationModal({
			text: this.item.dataset.confirm,
			confirmationClass: "alert",
			cancelable: true,
			confirmationCallback: () => {
				DataCycle.httpRequest(this.item.href, { method: "DELETE" })
					.then(() => {
						this.item.closest("li").remove();
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

export default ClassificationDestroyButton;
