class AdditionalValuesFilterControl {
  constructor(config) {
    this.config = config;
  }
  onAdd(map) {
    this.map = map;

    this._setupControls();
    this._setupOverlay();
    this._addEventHandlers();

    return this.container;
  }
  onRemove() {
    this.container.parentNode.removeChild(this.container);
    this.map = undefined;
  }
  _setupControls() {
    this.container = document.createElement('div');
    this.container.className = 'mapboxgl-ctrl mapboxgl-ctrl-group additional-values-overlay-control';

    this.controlButton = document.createElement('button');
    this.controlButton.className = 'dc-additional-values-overlay-button';
    this.controlButton.type = 'button';
    this.controlButton.title = 'show Additional Value Filters';
    this.container.appendChild(this.controlButton);

    const icon = document.createElement('i');
    icon.className = 'fa fa-map-marker';
    this.controlButton.appendChild(icon);
  }
  _setupOverlay() {
    this.controlOverlay = document.createElement('div');
    this.controlOverlay.className = 'dc-additional-values-overlay remote-render';
    this.controlOverlay.dataset.remotePath = 'data_cycle_core/contents/editors/geographic/additional_values_overlay';
    this.controlOverlay.dataset.remoteOptions = JSON.stringify({ additional_values: this.config });

    this.map.getContainer().appendChild(this.controlOverlay);
  }
  _addEventHandlers() {
    this.controlButton.addEventListener('click', event => {
      event.preventDefault();
      event.stopPropagation();

      if (this.controlOverlay.classList.contains('active')) this.controlOverlay.classList.remove('active');
      else {
        this.controlOverlay.classList.add('active');

        if (this.controlOverlay.classList.contains('remote-render')) {
          this.controlOverlay.dispatchEvent(
            new CustomEvent('dc:remote:render', {
              bubbles: true
            })
          );
        }
      }
    });
  }
}

export default AdditionalValuesFilterControl;
