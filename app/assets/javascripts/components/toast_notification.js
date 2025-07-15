import lodashEscape from "lodash/escape";

const showTimeMapping = {
	alert: 10000,
	info: 8000,
	success: 5000,
	default: 5000,
};

const typeMapping = {
	error: "alert",
	warning: "info",
};

const persistentTypes = ["alert", "info"];

class ToastNotification {
	constructor(notificationContainer) {
		this.notificationContainer = notificationContainer;
		this.setUp();
	}

	setUp() {
		this.addMutationObserver();
		this.handleInitialNotifications();
	}

	addMutationObserver() {
		DataCycle.registerAddCallback(
			"div.flash-messages .new-notification",
			"dcjs-new-toast-notification",
			this.handleNotification.bind(this),
		);
	}

	handleNotification(node) {
		const text = node.dataset.text;
		const type = node.dataset.type;
		const closeable = node.hasAttribute("data-closable");

		this.showToastNotification(text, type, closeable);
		node.remove();
	}

	handleInitialNotifications() {
		if (this.notificationContainer.querySelector(".new-notification")) {
			for (const node of this.notificationContainer.querySelectorAll(
				".new-notification",
			)) {
				this.handleNotification(node);
			}
		}
	}

	showToastNotification(text, type = "", closeable = true) {
		showToast(text, type, closeable);
	}
}

export function showToast(text, type = "", closeable = true) {
	const mappedType = typeMapping[type] || type;
	const showTime = showTimeMapping[mappedType] || showTimeMapping.default;

	let autoDismiss = !persistentTypes.includes(mappedType);
	autoDismiss = closeable ? autoDismiss : true; // if not closeable, always auto dismiss. Otherwise, it would be impossible to dismiss the notification.

	const toast = document.createElement("div");
	toast.classList.add("flash-notification", "toast-notification", mappedType);
	toast.setAttribute("data-text", lodashEscape(text));
	toast.setAttribute("data-type", mappedType);
	if (autoDismiss) {
		toast.setAttribute("data-auto-dismiss", "");
	}
	toast.style.setProperty("--_time", `${showTime}ms`);
	if (closeable) {
		toast.setAttribute("data-closable", "");
	}
	toast.innerHTML = `
    ${text}
    ${
			closeable
				? `<button
            name="button"
            type="button"
            class="close-button"
            data-close
            aria-label="Dismiss alert"
          >
            <span aria-hidden="true">×</span>
          </button>`
				: ""
		}
  ${autoDismiss ? '<div class="toast-timer-bar"></div>' : ""}
  `;

	const container = document.querySelector(".flash-messages");
	container?.appendChild(toast);

	toast.addEventListener("animationend", (event) => {
		if (event.animationName === "slideIn") {
			toast.classList.add("in-visible-transition-state");
		}

		if (event.animationName === "slideOut") {
			toast.remove();
		}
	});

	toast.addEventListener("animationstart", (event) => {
		if (event.animationName === "slideOut") {
			toast.classList.remove("in-visible-transition-state");
		}
	});
}

export default ToastNotification;
