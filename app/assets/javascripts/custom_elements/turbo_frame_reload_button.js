export default class TurboFrameReloadButton extends HTMLButtonElement {
	#turboFrame;

	constructor() {
		super();

		this.type = "button"; // Ensure the button is of type button to prevent form submission
		this.#turboFrame = this.closest("turbo-frame");
		this.addEventListener("click", this.#reloadTurboFrame.bind(this));
	}
	static registeredName = "turbo-frame-reload-button";
	static options = { extends: "button" };

	#reloadTurboFrame(event) {
		event.preventDefault();

		if (this.#turboFrame) this.#turboFrame.reload();
	}
}
