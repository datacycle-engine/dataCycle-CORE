class UndoRedoControl {
	constructor(editor) {
		this.editor = editor;
		this._currentStep = 0;
		this._stepHistory = [];
		this.mtkEditor = this.editor.editorGui.editor;
	}
	onAdd(map) {
		this.map = map;

		this._setupControls();
		this._addEventHandlers();

		return this.container;
	}
	onRemove() {
		this.container.parentNode.removeChild(this.container);
		this.map = undefined;
	}
	_setupControls() {
		this.container = document.createElement("div");
		this.container.className =
			"maplibregl-ctrl maplibregl-ctrl-group undo-control";

		this.controlUndoButton = document.createElement("button");
		this.controlUndoButton.className = "dc-undo-button";
		this.controlUndoButton.type = "button";
		I18n.translate("frontend.map.undo").then((text) => {
			this.controlUndoButton.title = text;
		});
		this.container.appendChild(this.controlUndoButton);

		const iconUndo = document.createElement("i");
		iconUndo.className = "fa fa-undo";
		this.controlUndoButton.appendChild(iconUndo);

		this.controlRedoButton = document.createElement("button");
		this.controlRedoButton.className = "dc-redo-button";
		this.controlRedoButton.type = "button";
		I18n.translate("frontend.map.redo").then((text) => {
			this.controlRedoButton.title = text;
		});
		this.container.appendChild(this.controlRedoButton);

		const iconRedo = document.createElement("i");
		iconRedo.className = "fa fa-repeat";
		this.controlRedoButton.appendChild(iconRedo);
	}
	_addEventHandlers() {
		this.controlUndoButton.addEventListener("click", this._undo.bind(this));
		this.controlRedoButton.addEventListener("click", this._redo.bind(this));

		MTK.event.addListener(this.mtkEditor, "update", () => {
			if (!this._userChangedStep) {
				if (this._currentStep < this._stepHistory.length - 1)
					this._stepHistory = this._stepHistory.splice(
						0,
						this._currentStep + 1,
					);
				this._stepHistory.push(this.mtkEditor.getWaypoints());
				this._currentStep = this._stepHistory.length - 1;
			}
			this._userChangedStep = false;
		});
	}
	_undo(event) {
		event.preventDefault();
		event.stopPropagation();

		if (this._stepHistory.length < 1) return;

		this._userChangedStep = true;
		--this._currentStep;
		this.mtkEditor.setWaypoints(this._stepHistory[this._currentStep] || []);
	}
	_redo(event) {
		event.preventDefault();
		event.stopPropagation();

		if (this._currentStep + 1 > this._stepHistory.length - 1) return;

		this._userChangedStep = true;
		++this._currentStep;
		this.mtkEditor.setWaypoints(this._stepHistory[this._currentStep] || []);
	}
}

export default UndoRedoControl;
