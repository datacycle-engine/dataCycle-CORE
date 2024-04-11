class MaplibreDrawControl {
	constructor(opts) {
		this.editor = opts.editor;
		this.draw = opts.draw;
		this.container;
		this.availableControls = [
			{
				key: "trash",
				action: this.trashControl.bind(this),
				class: "mapbox-gl-draw_trash",
			},
			{
				key: "draw_point",
				action: this.drawModeControl.bind(this, "draw_point"),
				class: "mapbox-gl-draw_point",
			},
			{
				key: "draw_line_string",
				action: this.drawModeControl.bind(this, "draw_line_string"),
				class: "mapbox-gl-draw_line",
			},
			{
				key: "draw_line_string_auto",
				action: this.drawModeControl.bind(this, "draw_line_string_auto"),
				class: "mapbox-gl-draw_line_auto",
			},
			{
				key: "draw_line_string_bicycle",
				action: this.drawModeControl.bind(this, "draw_line_string_bicycle"),
				class: "mapbox-gl-draw_line_bicycle",
			},
			{
				key: "draw_line_string_pedestrian",
				action: this.drawModeControl.bind(this, "draw_line_string_pedestrian"),
				class: "mapbox-gl-draw_line_pedestrian",
			},
		];
		this.controls = this.availableControls.filter((v) =>
			opts.controls.includes(v.key),
		);
	}
	onAdd(map) {
		this.map = map;

		this.map.on("draw.modechange", (event) => {
			this.setActiveButton(event.mode);
		});

		this.container = this.draw.onAdd(map);

		for (const btn of this.controls) this.addButton(btn);

		return this.container;
	}
	onRemove(map) {
		for (const btn of this.controls) this.removeButton(btn);

		this.map = undefined;
		this.draw.onRemove(map);
	}

	addButton(opt) {
		const button = document.createElement("button");
		button.className = `mapbox-gl-draw_ctrl-draw-btn dc-map-control-button ${opt.key} ${opt.class}`;
		if (opt.key === this.draw.getMode()) button.classList.add("active");

		I18n.translate(`frontend.map.buttons.${opt.key}`).then((text) => {
			button.title = text;
		});
		button.addEventListener("click", opt.action);

		opt.el = button;

		this.container.appendChild(button);
	}
	removeButton(opt) {
		opt.el.removeEventListener("click", opt.action);
		opt.el.remove();
	}
	setActiveButton(key) {
		for (const btn of this.container.getElementsByClassName(
			"dc-map-control-button",
		))
			btn.classList.remove("active");

		if (key)
			this.container
				.querySelector(`.dc-map-control-button.${key}`)
				?.classList.add("active");
	}
	trashControl(e) {
		e.preventDefault();
		e.stopPropagation();
		this.editor.draw.trash();
	}
	drawModeControl(m, e) {
		e.preventDefault();
		e.stopPropagation();

		if (this.editor.additionalValuesFilterControl?.enabled) return;

		const previousMode = this.editor.draw.getMode();
		// temporarily change mode to simple_select to disable active drawing mode
		if (previousMode !== "simple_select")
			this.editor.draw.changeMode("simple_select", {}, { silent: true });

		const { mode, options } = this.editor.getMapDrawMode(m);
		this.editor.draw.changeMode(mode, options);
		this.map.fire("draw.modechange", { mode: mode });

		this.setActiveButton(mode);
	}
}

export default MaplibreDrawControl;
