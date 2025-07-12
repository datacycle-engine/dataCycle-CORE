export default class TurboFrameEvents {
	static selector = "turbo-frame";
	static className = "dcjs-turbo-frame-events";
	constructor(element) {
		this.element = element;

		this.element.addEventListener(
			"turbo:fetch-request-error",
			this.#handleFetchError.bind(this),
		);
		this.element.addEventListener(
			"turbo:frame-missing",
			this.#handleFetchError.bind(this),
		);
	}

	async #handleFetchError(event) {
		event.preventDefault();

		this.element.innerHTML = `<div class="remote-render-error">${await I18n.translate(
			"frontend.remote_render.error",
		)}<button is="turbo-frame-reload-button" class="remote-reload-link"><i class="fa fa-repeat" aria-hidden="true"></i> ${await I18n.t(
			"frontend.remote_render.reload",
		)}</button></div>`;
	}
}
