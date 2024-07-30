class OffCanvasClickHandler {
	constructor(item) {
		this.offCanvas = item;
		this.$offCanvas = $(this.offCanvas);
		this.offCanvas.classList.add("dcjs-offcanvas-click-handler");
		this.clickHandlers = {
			close: this.closeOffCanvas.bind(this),
		};

		this.setup();
	}
	setup() {
		this.$offCanvas.on(
			"opened.zf.offCanvas",
			this.enableClickHandler.bind(this),
		);

		this.$offCanvas.on(
			"close.zf.offCanvas",
			this.disableClickHandler.bind(this),
		);
	}
	enableClickHandler() {
		document.body.addEventListener("click", this.clickHandlers.close);
	}
	disableClickHandler() {
		document.body.removeEventListener("click", this.clickHandlers.close);
	}
	closeOffCanvas(e) {
		if (
			e.target.closest("button.show-sidebar") ||
			e.target.closest("#settings-off-canvas")
		)
			return;

		if (typeof this.$offCanvas.foundation === "function")
			this.$offCanvas.foundation("close");
	}
}

export default OffCanvasClickHandler;
