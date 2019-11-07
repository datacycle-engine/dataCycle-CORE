var ConfirmationModal = require('./../components/confirmation_modal');
var OpenLayerMaps = require('./../components/open_layer_maps');

// Map Configuration
module.exports.initialize = function() {
  if ($('.object-browser-overlay .item-info-scrollable').length) {
    $('.object-browser-overlay .item-info-scrollable').on('details-changed', event => {
      $(event.target)
        .find('.geographic-map')
        .each((index, item) => {
          init_map(item);
        });
    });
  }

  if ($('.geographic-map').length) {
    $('.geographic-map').each((index, item) => {
      init_map(item);
    });
  }

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    $(event.target)
      .find('.geographic-map')
      .each((index, item) => {
        init_map(item);
      });
  });
};

function init_map(item) {
  if ($(item).hasClass('edit') && $(item).hasClass('point')) {
    drawable = false;
    feature = new ol.Feature({
      geometry: new ol.geom.Point($(item).data('after-position'))
    });
    feature_old = new ol.Feature({
      geometry: new ol.geom.Point($(item).data('before-position'))
    });

    feature.setStyle(greenIconStyle);
    feature_old.setStyle(redIconStyle);
  } else if (data.type == 'Point' && data.points[0].length > 0) {
    drawable = false;
    feature = new ol.Feature({
      geometry: new ol.geom.Point(data.points[0])
    });
    if (iconStyle !== undefined) feature.setStyle(iconStyle);
  } else if (data.type == 'LineString') {
    feature = new ol.Feature({
      geometry: new ol.geom.LineString(data.points)
    });
  }

  $(item).on('dc:import:data', (event, data) => {
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
  });

  var options = {};
  var features = [];
  if (feature !== undefined) features.push(feature);
  if (feature_old !== undefined) features.push(feature_old);

  if (features.length > 0) {
    features.forEach(item => {
      item.getGeometry().transform('EPSG:4326', 'EPSG:3857');
    });
    options = {
      features: features
    };
  }

  var source = new ol.source.Vector(options);

  var layerLines = new ol.layer.Vector({
    source: source,
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

  var mouse_wheel_zoom = new ol.interaction.MouseWheelZoom();

  var timeout;

  var oldFn = mouse_wheel_zoom.handleEvent;
  mouse_wheel_zoom.handleEvent = function(e) {
    var type = e.type;
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

      window.clearTimeout(timeout);
      timeout = window.setTimeout(() => {
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

  var map = new ol.Map({
    interactions: ol.interactions
      .defaults({
        mouseWheelZoom: false
      })
      .extend([mouse_wheel_zoom]),
    target: map_id,
    layers: [
      new ol.layer.Tile({
        source: new ol.source.OSM()
      }),
      layerLines
    ],
    view: new ol.View({
      center: [0, 0],
      zoom: 10
    })
  });

  map.on('pointermove', function(evt) {
    var hit = evt.map.hasFeatureAtPixel(evt.pixel);
    evt.map.getTargetElement().firstElementChild.style.cursor = evt.dragging ? 'grabbing' : hit ? 'pointer' : '';
  });

  if ($(item).hasClass('editable')) {
    var modify = new ol.interaction.Modify({
      source: source
    });
    map.addInteraction(modify);
    var draw;

    if (drawable) {
      draw = new ol.interaction.Draw({
        source: source,
        type: 'Point'
      });
      map.addInteraction(draw);

      draw.on('drawend', event => {
        drawable = false;
        feature = event.feature;
        if (iconStyle !== undefined) feature.setStyle(iconStyle);
        map.removeInteraction(draw);
        setCoordinates(item, feature.getGeometry().getCoordinates());
        setHiddenFieldValue(item, feature.getGeometry().getCoordinates());
      });
    }

    var snap = new ol.interaction.Snap({
      source: source
    });
    map.addInteraction(snap);

    var modifying = false;

    modify.on('modifystart', () => {
      modifying = true;
    });

    modify.on('modifyend', () => {
      modifying = false;
      if (feature !== undefined) {
        setHiddenFieldValue(item, feature.getGeometry().getCoordinates());
      }
    });

    map.on('pointerdrag', event => {
      if (modifying && feature !== undefined) {
        setCoordinates(item, feature.getGeometry().getCoordinates());
      }
    });

    // Geocoding Functionality
    $('.geocode-address-button').on('click', event => {
      event.preventDefault();
      $(event.currentTarget).append(' <i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>');

      var address_key = $(event.currentTarget).data('address-key');
      var address = {};

      $('.form-element.object.' + address_key)
        .find('.form-element')
        .find('input')
        .each((index, elem) => {
          address[elem.name.get_key()] = elem.value;
        });

      $.getJSON('/things/geocode_address/', address)
        .done(data => {
          if (data.error !== undefined) {
            console.log(data.error);
          } else if (data !== undefined && data.length == 2 && feature !== undefined) {
            feature.setGeometry(new ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857'));
            setNewCoordinates(item, map, feature);
          } else if (data !== undefined && data.length == 2 && feature === undefined) {
            feature = new ol.Feature({
              geometry: new ol.geom.Point(data).transform('EPSG:4326', 'EPSG:3857')
            });
            if (iconStyle !== undefined) feature.setStyle(iconStyle);
            source.addFeature(feature);
            map.removeInteraction(draw);
            setNewCoordinates(item, map, feature);
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
    });

    $(item)
      .parent('.geographic')
      .siblings('.map-info')
      .first()
      .find('.longitude input, .latitude  input')
      .on('change', event => {
        var valid = true;
        var coords = getCoordinates(item);
        coords.forEach(element => {
          valid = valid && !isNaN(element);
        });

        if (valid && feature !== undefined) {
          feature.setGeometry(new ol.geom.Point(getCoordinates(item)).transform('EPSG:4326', 'EPSG:3857'));
          setNewCoordinates(item, map, feature);
        } else if (valid && feature === undefined) {
          feature = new ol.Feature({
            geometry: new ol.geom.Point(getCoordinates(item)).transform('EPSG:4326', 'EPSG:3857')
          });
          if (iconStyle !== undefined) feature.setStyle(iconStyle);
          source.addFeature(feature);
          map.removeInteraction(draw);
          setNewCoordinates(item, map, feature);
        }
      });
  }

  if (data.type == 'Point' && feature !== undefined) {
    map.getView().setCenter(feature.getGeometry().getCoordinates());
  } else if (data.type == 'LineString') {
    map.getView().fit(feature.getGeometry());
  } else {
    var default_position = $(item).data('default-position');
    if (
      default_position !== undefined &&
      default_position.longitude !== undefined &&
      default_position.latitude !== undefined
    ) {
      var newCoords = new ol.geom.Point([default_position.longitude, default_position.latitude]).transform(
        'EPSG:4326',
        'EPSG:3857'
      );
      map.getView().setCenter(newCoords.getCoordinates());
    }
    if (default_position !== undefined && default_position.zoom !== undefined)
      map.getView().setZoom(default_position.zoom);
  }
}
