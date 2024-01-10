import ConfirmationModal from "./../components/confirmation_modal";

export default function () {
	Rails.confirm = function (message, element) {
		if (element.dataset.confirmed) return true;

		new ConfirmationModal({
			text: message,
			confirmationClass: "alert",
			cancelable: true,
			confirmationCallback: () => {
				element.dataset.confirmed = true;
				element.click();
			},
		});

		return false;
	};
}
