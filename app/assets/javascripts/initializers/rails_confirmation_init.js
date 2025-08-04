import ConfirmationModal from "./../components/confirmation_modal";

export function turboConfirmMethod(message, element) {
	return new Promise((resolve) => {
		new ConfirmationModal({
			text: message,
			confirmationText: element.dataset.confirmationText,
			confirmationHeaderText: element.dataset.confirmationHeaderText,
			confirmationClass: element.dataset.confirmationClass || "alert",
			cancelable: true,
			confirmationCallback: resolve.bind(resolve, true),
			cancelCallback: resolve.bind(resolve, false),
		});
	});
}

export default function () {
	Rails.confirm = (message, element) => {
		if (element.dataset.confirmed) return true;

		new ConfirmationModal({
			text: message,
			confirmationText: element.dataset.confirmationText,
			confirmationHeaderText: element.dataset.confirmationHeaderText,
			confirmationClass: element.dataset.confirmationClass || "alert",
			cancelable: true,
			confirmationCallback: () => {
				element.dataset.confirmed = true;
				element.click();
			},
		});

		return false;
	};
}
