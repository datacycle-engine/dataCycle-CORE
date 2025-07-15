class MaplibreElevationProfileControl {
	constructor(opts = {}) {
		this.container;
		this.toggleHandler = this._toggleElevationProfile.bind(this);
		this.expanded = false;
		this.thingId = opts.thingId;
	}
	_setupControls() {
		this.container = document.createElement('div');
		this.container.className =
			'maplibregl-ctrl maplibregl-ctrl-group mapboxgl-ctrl mapboxgl-ctrl-group elevation-profile';

		this.elevationProfileContainer = document.createElement('div');
		this.elevationProfileContainer.className =
			'elevation-profile-container dc-elevation-profile-chart';
		this.elevationProfileContainer.dataset.thingId = this.thingId;

		this.controlButton = document.createElement('button');
		this.controlButton.className = 'elevation-profile-button';
		this.controlButton.type = 'button';
		I18n.translate('frontend.map.elevation_profile.button_title').then(
			(text) => {
				this.controlButton.title = text;
			},
		);
		this.container.appendChild(this.elevationProfileContainer);
		this.container.appendChild(this.controlButton);

		this.controlButtonIcon = document.createElement('i');
		this.controlButtonIcon.className = 'fa fa-line-chart';
		this.controlButton.appendChild(this.controlButtonIcon);
	}
	onAdd(map) {
		this.map = map;

		this._setupControls();

		this.controlButton.addEventListener('click', this.toggleHandler);

		return this.container;
	}
	onRemove(_map) {
		this.controlButton.removeEventListener('click', this.toggleHandler);
		this.container.remove();

		this.map = undefined;
	}
	_toggleElevationProfile(event) {
		event.preventDefault();
		event.stopImmediatePropagation();

		this.expanded = this.container.classList.toggle('expanded');
		this.controlButtonIcon.classList.toggle('fa-line-chart', !this.expanded);
		this.controlButtonIcon.classList.toggle('fa-times', this.expanded);
	}
}

export default MaplibreElevationProfileControl;
