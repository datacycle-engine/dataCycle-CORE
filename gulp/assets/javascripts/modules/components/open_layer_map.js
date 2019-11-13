var ConfirmationModal = require('./confirmation_modal');
var ObjectHelpers = require('./../helpers/object_helpers');

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

class OpenLayerMap {
  constructor(container) {
    this.container = $(container);
    this.target = this.container.attr('id');
    this.value = this.container.data('value');
    this.beforeValue = this.container.data('before-position');
    this.afterValue = this.container.data('after-position');
    this.type = this.container.data('type');
    this.iconPaths = this.container.data('icon-paths');
    this.editable = this.container.parent('.geographic').hasClass('editable');
    this.feature;
    this.featureOld;
    this.drawable = true;
    this.iconStyle;
    this.redIconStyle;
    this.greenIconStyle;
    this.redLineStyle;
    this.defaultLineStyle;
    this.greenLineStyle;
    this.options = {};
    this.features = [];
    this.source;
    this.layerLines;
    this.mouseWheelZoom = new ol.interaction.MouseWheelZoom();
    this.mouseZoomTimeout;
    this.map;
    this.modify;
    this.draw;
    this.modifying = false;
    this.geoCodeButton = $('.geocode-address-button');
    this.mapOptions = this.container.data('map-options');
    this.defaultPosition = ObjectHelpers.select(this.mapOptions, ['latitude', 'longitude', 'zoom']);

    this.setup();
  }
  setup() {
    this.initIconStyles();
    this.initFeatures();
    this.initEventHandlers();
    this.configureFeatures();
    this.configureLayerLines();
    this.initMouseWheelZoom();
    this.initMap();
    this.initMapActions();
    this.setDefaultPosition();
  }
  initIconStyles() {
    if (this.iconPaths !== undefined) {
      this.iconStyle = new ol.style.Style({
        image: new ol.style.Icon({
          anchor: [16, 32],
          anchorXUnits: 'pixels',
          anchorYUnits: 'pixels',
          src: this.iconPaths.default
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
    this.defaultLineStyle = new ol.style.Style({
      stroke: new ol.style.Stroke({ color: '#1779ba', width: 5 })
    });
    this.redLineStyle = new ol.style.Style({
      stroke: new ol.style.Stroke({ color: '#cc4b37', width: 5 })
    });
    this.greenLineStyle = new ol.style.Style({
      stroke: new ol.style.Stroke({ color: '#90c062', width: 5 })
    });
  }
  initFeatures() {
    if (
      this.type == 'Point' &&
      ((this.afterValue !== undefined && this.afterValue[0] !== undefined) ||
        (this.beforeValue !== undefined && this.beforeValue[0] !== undefined))
    ) {
      this.drawable = false;
      if (this.afterValue !== undefined && this.afterValue[0] !== undefined && this.afterValue[0].length > 0) {
        this.feature = new ol.Feature({
          geometry: new ol.geom.Point(this.afterValue[0])
        });
        this.feature.setStyle(this.greenIconStyle);
      }

      if (this.beforeValue !== undefined && this.beforeValue[0] !== undefined && this.beforeValue[0].length > 0) {
        this.featureOld = new ol.Feature({
          geometry: new ol.geom.Point(this.beforeValue[0])
        });
        this.featureOld.setStyle(this.redIconStyle);
      }
    } else if (this.type == 'Point' && this.value[0].length > 0) {
      this.drawable = false;
      this.feature = new ol.Feature({
        geometry: new ol.geom.Point(this.value[0])
      });
      if (this.iconStyle !== undefined) this.feature.setStyle(this.iconStyle);
    } else if (
      this.type == 'LineString' &&
      ((this.afterValue !== undefined && this.afterValue[0] !== undefined) ||
        (this.beforeValue !== undefined && this.beforeValue[0] !== undefined))
    ) {
      let points = [];
      if (this.afterValue !== undefined && this.afterValue[0] !== undefined && this.afterValue[0].length > 0) {
        points.push(this.afterValue);
        this.feature = new ol.Feature({
          geometry: new ol.geom.LineString(this.afterValue)
        });
        this.feature.setStyle(this.greenLineStyle);
      }
      if (this.beforeValue !== undefined && this.beforeValue[0] !== undefined && this.beforeValue[0].length > 0) {
        points.push(this.beforeValue);
        this.featureOld = new ol.Feature({
          geometry: new ol.geom.LineString(this.beforeValue)
        });
        this.featureOld.setStyle(this.redLineStyle);
      }
    } else if (this.type == 'LineString') {
      this.feature = new ol.Feature({
        geometry: new ol.geom.LineString(this.value)
      });
      this.feature.setStyle(this.defaultLineStyle);
    }
  }
  initEventHandlers() {
    this.container.on('dc:import:data', this.importData.bind(this));
  }
  importData(event, data) {
    let form_fields = $(event.target)
      .parent('.geographic')
      .siblings('.map-info')
      .first();

    if (
      form_fields.find('.form-element.elevation > input').val().length == 0 &&
      $(event.target)
        .parent('.geographic')
        .siblings('input.location-data:hidden')
        .first()
        .val().length == 0
    ) {
      form_fields.find('.form-element.elevation > input').val(data.value.elevation);
      form_fields
        .find('.form-element.latitude > input')
        .val(data.value.y)
        .trigger('change');
      form_fields
        .find('.form-element.longitude > input')
        .val(data.value.x)
        .trigger('change');
    } else {
      var confirmationModal = new ConfirmationModal({
        text: 'Soll das Feld "' + data.label + '" überschrieben werden?',
        confirmationText: 'Ja',
        cancelText: 'Nein',
        confirmationClass: 'success',
        cancelable: true,
        confirmationCallback: function() {
          form_fields.find('.form-element.elevation > input').val(data.value.elevation);
          form_fields
            .find('.form-element.latitude > input')
            .val(data.value.y)
            .trigger('change');
          form_fields
            .find('.form-element.longitude > input')
            .val(data.value.x)
            .trigger('change');
        }.bind(this)
      });
    }
  }
  configureFeatures() {
    if (this.feature !== undefined) this.features.push(this.feature);
    if (this.featureOld !== undefined) this.features.push(this.featureOld);

    if (this.features.length > 0) {
      this.features.forEach(item => {
        item.getGeometry().transform('EPSG:4326', 'EPSG:3857');
      });
      this.options = {
        features: this.features
      };
    }
  }
  configureLayerLines() {
    this.source = new ol.source.Vector(this.options);

    this.layerLines = new ol.layer.Vector({
      source: this.source,
      style: [
        new ol.style.Style({
          stroke: new ol.style.Stroke({
            color: '#c30000',
            width: 3
          }),
          image: new ol.style.Circle({
            radius: 3,
            fill: new ol.style.Fill({
              color: '#c30000'
            }),
            stroke: new ol.style.Stroke({
              color: '#c30000',
              width: 3
            })
          })
        })
      ]
    });
  }
  initMouseWheelZoom() {
    let oldFn = this.mouseWheelZoom.handleEvent;
    let self = this;

    this.mouseWheelZoom.handleEvent = function(e) {
      let type = e.type;
      if (type !== 'wheel') {
        return true;
      }

      if (!e.originalEvent.ctrlKey) {
        if (!$(e.map.getTargetElement().firstElementChild).find('.scroll-overlay').length) {
          $(e.map.getTargetElement().firstElementChild)
            .find('canvas')
            .after(
              '<div class="scroll-overlay" style="display: none;"><div class="scroll-overlay-text">Verwende Strg+Scrollen zum Zoomen der Karte</div></div>'
            );
        } else {
          $(e.map.getTargetElement().firstElementChild)
            .find('.scroll-overlay')
            .fadeIn(100);
        }

        window.clearTimeout(self.mouseZoomTimeout);
        self.mouseZoomTimeout = window.setTimeout(() => {
          $(e.map.getTargetElement().firstElementChild)
            .find('.scroll-overlay')
            .fadeOut(100);
        }, 1000);
        return true;
      } else {
        $(e.map.getTargetElement().firstElementChild)
          .find('.scroll-overlay')
          .fadeOut(100);
      }

      oldFn.call(this, e);
    };
  }
  initMap() {
    this.map = new ol.Map({
      interactions: ol.interactions
        .defaults({
          mouseWheelZoom: false
        })
        .extend([this.mouseWheelZoom]),
      target: this.target,
      layers: [
        new ol.layer.Tile({
          source: new ol.source.OSM()
        }),
        this.layerLines
      ],
      view: new ol.View({
        center: [0, 0],
        zoom: 10
      })
    });
  }
  initMapActions() {
    this.map.on('pointermove', evt => {
      let hit = evt.map.hasFeatureAtPixel(evt.pixel);
      evt.map.getTargetElement().firstElementChild.style.cursor = evt.dragging ? 'grabbing' : hit ? 'pointer' : '';
    });

    if (this.editable) this.initMapEditActions();
  }
  initMapDrawableActions() {
    this.draw = new ol.interaction.Draw({
      source: this.source,
      type: 'Point'
    });
    this.map.addInteraction(this.draw);

    this.draw.on('drawend', event => {
      this.drawable = false;
      this.feature = event.feature;
      if (this.iconStyle !== undefined) this.feature.setStyle(this.iconStyle);
      this.map.removeInteraction(this.draw);
      this.setCoordinates();
      this.setHiddenFieldValue();
    });
  }
  initGeoCodingActions(event) {
    event.preventDefault();

    $(event.currentTarget).append(' <i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>');

    let addressKey = $(event.currentTarget).data('address-key');
    let address = {};

    $('.form-element.object.' + addressKey)
      .find('.form-element')
      .find('input')
      .each((index, elem) => {
        address[elem.name.get_key()] = elem.value;
      });

    $.getJSON('/things/geocode_address/', address)
      .done(data => {
        if (data.error !== undefined) {
          console.log(data.error);
        } else if (data !== undefined && data.length == 2 && this.feature !== undefined) {
          this.feature.setGeometry(new ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857'));
          this.setNewCoordinates();
        } else if (data !== undefined && data.length == 2 && this.feature === undefined) {
          this.feature = new ol.Feature({
            geometry: new ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857')
          });
          if (this.iconStyle !== undefined) this.feature.setStyle(this.iconStyle);
          this.source.addFeature(this.feature);
          this.map.removeInteraction(this.draw);
          this.setNewCoordinates();
        }
      })
      .fail((jqxhr, textStatus, error) => {
        console.log(textStatus + ', ' + error);
      })
      .always(() => {
        $(event.currentTarget)
          .find('i.fa')
          .remove();
      });
  }
  updateMapMarker(event) {
    let valid = true;
    let coords = this.getCoordinates();
    coords.forEach(element => {
      valid = valid && !isNaN(element);
    });

    if (valid && this.feature !== undefined) {
      this.feature.setGeometry(new ol.geom.Point(this.getCoordinates()).transform('EPSG:4326', 'EPSG:3857'));
      this.setNewCoordinates();
    } else if (valid && this.feature === undefined) {
      this.feature = new ol.Feature({
        geometry: new ol.geom.Point(this.getCoordinates()).transform('EPSG:4326', 'EPSG:3857')
      });
      if (this.iconStyle !== undefined) this.feature.setStyle(this.iconStyle);
      this.source.addFeature(this.feature);
      this.map.removeInteraction(this.draw);
      this.setNewCoordinates();
    }
  }
  initMapEditActions() {
    this.modify = new ol.interaction.Modify({
      source: this.source
    });
    this.map.addInteraction(this.modify);
    if (this.drawable) this.initMapDrawableActions();

    let snap = new ol.interaction.Snap({
      source: this.source
    });
    this.map.addInteraction(snap);

    this.modify.on('modifystart', () => {
      this.modifying = true;
    });

    this.modify.on('modifyend', () => {
      this.modifying = false;
      if (this.feature !== undefined) {
        this.setHiddenFieldValue();
      }
    });

    this.map.on('pointerdrag', event => {
      if (this.modifying && this.feature !== undefined) {
        this.setCoordinates();
      }
    });

    if (this.geoCodeButton !== undefined) this.geoCodeButton.on('click', this.initGeoCodingActions.bind(this));

    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.longitude input, .latitude  input')
      .on('change', this.updateMapMarker.bind(this));
  }
  getLatLon(coords) {
    return ol.proj.transform(coords, 'EPSG:3857', 'EPSG:4326');
  }
  setNewCoordinates() {
    this.setCoordinates();
    this.setHiddenFieldValue();
    this.map.getView().setCenter(this.feature.getGeometry().getCoordinates());
  }
  setCoordinates() {
    let coords = this.feature.getGeometry().getCoordinates();
    let latlon = this.getLatLon(coords);
    latlon[0] = Number(latlon[0].toFixed(5));
    latlon[1] = Number(latlon[1].toFixed(5));
    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.longitude input')
      .val(latlon[0]);
    this.container
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.latitude input')
      .val(latlon[1]);
  }
  getCoordinates() {
    return [
      parseFloat(
        this.container
          .parent('.geographic')
          .siblings('.map-info')
          .first()
          .find('.longitude input')
          .val()
      ),
      parseFloat(
        this.container
          .parent('.geographic')
          .siblings('.map-info')
          .first()
          .find('.latitude input')
          .val()
      )
    ];
  }
  setHiddenFieldValue() {
    let coords = this.feature.getGeometry().getCoordinates();
    let latlon = this.getLatLon(coords);
    latlon[0] = Number(latlon[0].toFixed(5));
    latlon[1] = Number(latlon[1].toFixed(5));
    this.container
      .parent('.geographic')
      .siblings('.location-data')
      .first()
      .val('POINT (' + latlon[0] + ' ' + latlon[1] + ')');
  }
  setDefaultPosition() {
    if (
      (this.type == 'LineString' && (this.feature !== undefined || this.featureOld !== undefined)) ||
      (this.feature !== undefined && this.featureOld !== undefined)
    ) {
      let extent = new ol.extent.createEmpty();
      if (this.feature !== undefined) extent = new ol.extent.extend(extent, this.feature.getGeometry().getExtent());
      if (this.featureOld !== undefined)
        extent = new ol.extent.extend(extent, this.featureOld.getGeometry().getExtent());
      this.map.getView().fit(extent, { padding: [50, 50, 50, 50] });
    } else if (this.type == 'Point' && (this.feature !== undefined || this.featureOld !== undefined)) {
      this.map.getView().setCenter((this.feature || this.featureOld).getGeometry().getCoordinates());
    } else {
      if (
        this.defaultPosition !== undefined &&
        this.defaultPosition.longitude !== undefined &&
        this.defaultPosition.latitude !== undefined
      ) {
        let newCoords = new ol.geom.Point([this.defaultPosition.longitude, this.defaultPosition.latitude]).transform(
          'EPSG:4326',
          'EPSG:3857'
        );
        this.map.getView().setCenter(newCoords.getCoordinates());
      }
      if (this.defaultPosition !== undefined && this.defaultPosition.zoom !== undefined)
        this.map.getView().setZoom(this.defaultPosition.zoom);
    }
  }
}

module.exports = OpenLayerMap;
