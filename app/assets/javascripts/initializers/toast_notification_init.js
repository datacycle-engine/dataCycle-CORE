import ToastNotification from "../components/toast_notification";

export default function () {
	if (
		document.querySelector(
			"div.flash-messages:not(.dcjs-toast-notification)",
		) === null
	) {
		const toastMessages = document.createElement("div");
		toastMessages.classList.add("flash-messages");
		document.body.prepend(toastMessages);
	}
	DataCycle.registerAddCallback(
		"div.flash-messages",
		"toast-notification",
		(e) => new ToastNotification(e),
	);
}
