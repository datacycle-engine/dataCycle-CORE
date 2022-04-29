class UploadGpxControl {
  constructor(editor) {
    this.editor = editor;
    // this.config = editor.additionalValuesOverlay;
    // this.activeFilters = {};
    // this.layerFilters = {};
    // this.geojsonValues = {};
    // this.lastLoadedFilter = {};
    // this.additionalSources = {};
    // this.additionalLayers = {};
    // this.additionalValueTargets = {};
    // this.enabled = false;
  }
  onAdd(map) {
    this.map = map;

    this._setupControls();

    this.editor.loadFile = function ($input) {
      this.uploadFile($input, (_err, d) => {
        this.setWaypoints(d.waypoints);

        b.fitBounds(d.bounds, { padding: 50 });
      });
    };

    this.container.addEventListener('click', event => {
      event.preventDefault();
      event.stopImmediatePropagation();
      console.log(event);
      // event.currentTarget.parentElement.querySelector('input[type="file"]').click();
    });

    const input = document.createElement('input');
    input.setAttribute('type', 'file');
    input.setAttribute('hidden', true);
    input.setAttribute('accept', '.gpx,.kml,.geojson');
    input.addEventListener('change', event => {
      event.preventDefault();
      event.stopImmediatePropagation();

      this.editor.loadFile(event.currentTarget);
    });

    return this.container;
  }
  onRemove() {
    this.container.parentNode.removeChild(this.container);
    this.map = undefined;
  }
  _setupControls() {
    this.container = document.createElement('div');
    this.container.className = 'mapboxgl-ctrl mapboxgl-ctrl-group upload-gpx-control';

    this.controlButton = document.createElement('button');
    this.controlButton.className = 'dc-upload-gpx-overlay-button';
    this.controlButton.type = 'button';
    I18n.translate('frontend.map.upload_gpx.button_title').then(text => (this.controlButton.title = text));
    this.container.appendChild(this.controlButton);

    const icon = document.createElement('i');
    icon.className = 'fa fa-upload';
    this.controlButton.appendChild(icon);
  }
}

export default UploadGpxControl;
