class TurboFrameReload {
	static selector = "turbo-frame[data-reload-interval]";
	static className = "dcjs-turbo-frame-reload";
	constructor(element) {
		this.element = element;

		this.interval =
			Number.parseInt(this.element.dataset.reloadInterval, 10) || 10;
		this.intervalHandler = setInterval(() => {
			this.element.reload();
		}, this.interval * 1000);
	}
}

export default TurboFrameReload;
