var ConfirmationModal = require('./confirmation_modal');

class TourSprungEditor {
  constructor(container) {
    this.container = $(container);
    this.target = this.container.attr('id');
    this.value = this.container.data('value');
    this.type = this.container.data('type');
    this.iconPath = this.container.data('icon-path');
    this.editable = this.container.hasClass('editable');
    this.defaultPosition = this.container.data('default-position');
    this.credentials = this.container.data('credentials');
    this.map;

    this.setup();
  }
  setup() {
    MTK.init({ apiKey: this.credentials.api_key });

    this.initMap();
  }
  initMap() {
    let defaultMapPosition = this.calculateCenter();
    let controls = [];

    if (this.editable) {
      let editor = this.configureEditor();
      if (editor !== undefined) controls.push(editor);
    }

    MTK.createMap(
      this.target,
      {
        map: {
          location: defaultMapPosition,
          mapType: 'terrain_v2',
          controls: controls
        }
      },
      this.configureMap.bind(this)
    );
  }
  configureMap(map) {
    this.map = map;

    if (this.type == 'Point' && this.value[0].length > 0) this.renderInitialMarker();
    else if (this.type == 'Point') this.creatableMarker();
  }
  creatableMarker() {
    this.map.on('click', event => {
      console.log('click');
    });
  }
  configureEditor() {
    if (this.type == 'LineString') {
      return new MTK.Control.Editor({
        undo: true,
        poi: false,
        wikipedia: false
      });
    }
  }
  calculateCenter() {
    if (this.type == 'Point' && this.value[0].length > 0) {
      return {
        center: $P(this.value[0][1], this.value[0][0]),
        zoom: 12
      };
    } else if (this.type == 'LineString' && this.value[0].length > 0) {
    } else if (
      this.defaultPosition !== undefined &&
      this.defaultPosition.longitude !== undefined &&
      this.defaultPosition.latitude !== undefined
    ) {
      return {
        center: $P(this.defaultPosition.latitude, this.defaultPosition.longitude),
        zoom: this.defaultPosition.zoom || 7
      };
    }
  }
  renderInitialMarker() {
    let marker = new L.Marker($P(this.value[0][1], this.value[0][0]), {
      draggable: this.editable,
      icon: L.icon({
        iconUrl: this.iconPath,
        iconAnchor: [16, 32]
      })
    })
      .addTo(this.map.leaflet)
      .on('dragend', () => {
        this.map.leaflet.setView(marker.getLatLng());
        this.setCoordinates(marker.getLatLng());
      });
  }
  setCoordinates(coords) {
    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.longitude input')
      .val(coords.lng);
    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.latitude input')
      .val(coords.lat);
    this.setHiddenFieldValue(coords);
  }
  setHiddenFieldValue(coords) {
    this.container
      .parent('.geographic')
      .siblings('.location-data')
      .first()
      .val('POINT (' + coords.lng + ' ' + coords.lat + ')');
  }
}

module.exports = TourSprungEditor;
