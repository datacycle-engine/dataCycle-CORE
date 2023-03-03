import AdditionalValuesFilterControl from "./maplibre_additional_values_filter_control";

class MtkAdditionalValuesFilterControl extends AdditionalValuesFilterControl {
	_addEventHandlers() {
		super._addEventHandlers();

		this.editor.mtkMap.on("maptypechanged", this._reloadOverlayData.bind(this));
	}
	_reloadOverlayData(_event = undefined) {
		for (const key of Object.keys(this.config)) {
			this._addGeoJsonSource(key, this.geojsonValues[key]);
			this._updateLayerVisibilities(key);
		}
	}
	_hideOverlay() {
		super._hideOverlay();

		this.editor.editorGui.editor.clickable = true;
		this.editor.editorGui.editor._enabled = true;
		this.editor.editorGui.editor.visibility = "visible";
	}
	_showOverlay() {
		super._showOverlay();

		this.editor.editorGui.editor.clickable = false;
		this.editor.editorGui.editor._enabled = false;
		this.editor.editorGui.editor.visibility = "none";
	}
}

export default MtkAdditionalValuesFilterControl;
