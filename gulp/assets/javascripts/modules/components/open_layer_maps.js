var ol = {
  Map: require('ol/map').default,
  layer: {
    Tile: require('ol/layer/tile').default,
    Vector: require('ol/layer/vector').default
  },
  Feature: require('ol/feature').default,
  geom: {
    Point: require('ol/geom/point').default,
    LineString: require('ol/geom/linestring').default
  },
  source: {
    OSM: require('ol/source/osm').default,
    Vector: require('ol/source/vector').default
  },
  style: {
    Style: require('ol/style/style').default,
    Stroke: require('ol/style/stroke').default,
    Circle: require('ol/style/circle').default,
    Fill: require('ol/style/fill').default,
    Text: require('ol/style/text').default,
    Icon: require('ol/style/icon').default
  },
  View: require('ol/view').default,
  extent: require('ol/extent').default,
  interaction: {
    Draw: require('ol/interaction/draw').default,
    Modify: require('ol/interaction/modify').default,
    Snap: require('ol/interaction/snap').default,
    MouseWheelZoom: require('ol/interaction/mousewheelzoom').default
  },
  interactions: require('ol/interaction').default,
  proj: require('ol/proj').default
};

class OpenLayerMaps {
  constructor(container) {
    this.container = $(container);
    this.value = this.container.data('value');
    this.type = this.container.data('type');
    this.iconPath = this.container.data('icon-path');
    this.editable = this.container.hasClass('edit');
    this.feature;
    this.featureOld;
    this.drawable = true;
    this.iconStyle;
    this.redIconStyle;
    this.greenIconStyle;

    this.setup();
  }
  setup() {
    this.initIconStyles();
  }
  initIconStyles() {
    if (this.iconPath !== undefined) {
      this.iconStyle = new ol.style.Style({
        image: new ol.style.Icon({
          anchor: [16, 32],
          anchorXUnits: 'pixels',
          anchorYUnits: 'pixels',
          src: this.iconPath
        })
      });
    } else {
      this.iconStyle = new ol.style.Style({
        image: new ol.style.Circle({
          radius: 7,
          fill: new ol.style.Fill({
            color: '#1779ba'
          }),
          stroke: new ol.style.Stroke({
            color: [0, 0, 0, 0.75],
            width: 1.5
          })
        }),
        zIndex: 100000
      });
    }
    this.redIconStyle = new ol.style.Style({
      image: new ol.style.Circle({
        radius: 7,
        fill: new ol.style.Fill({
          color: '#cc4b37'
        }),
        stroke: new ol.style.Stroke({
          color: [0, 0, 0, 0.75],
          width: 1.5
        })
      }),
      zIndex: 100000
    });

    this.greenIconStyle = new ol.style.Style({
      image: new ol.style.Circle({
        radius: 7,
        fill: new ol.style.Fill({
          color: '#90c062'
        }),
        stroke: new ol.style.Stroke({
          color: [0, 0, 0, 0.75],
          width: 1.5
        })
      }),
      zIndex: 100000
    });
  }
  getLatLon(coords) {
    return ol.proj.transform(coords, 'EPSG:3857', 'EPSG:4326');
  }
  setNewCoordinates(container, map, feature) {
    setCoordinates(container, feature.getGeometry().getCoordinates());
    setHiddenFieldValue(container, feature.getGeometry().getCoordinates());
    map.getView().setCenter(feature.getGeometry().getCoordinates());
  }
  setCoordinates(container, coords) {
    var latlon = getLatLon(coords);
    $(container)
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.longitude input')
      .val(latlon[0]);
    $(container)
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.latitude input')
      .val(latlon[1]);
  }
  getCoordinates(container) {
    return [
      parseFloat(
        $(container)
          .parent('.geographic')
          .siblings('.map-info')
          .first()
          .find('.longitude input')
          .val()
      ),
      parseFloat(
        $(container)
          .parent('.geographic')
          .siblings('.map-info')
          .first()
          .find('.latitude input')
          .val()
      )
    ];
  }
  setHiddenFieldValue(container, coords) {
    var latlon = getLatLon(coords);
    $(container)
      .parent('.geographic')
      .siblings('.location-data')
      .first()
      .val('POINT (' + latlon[0] + ' ' + latlon[1] + ')');
  }
}

module.exports = OpenLayerMaps;
