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
    Snap: require('ol/interaction/snap').default
  },
  proj: require('ol/proj').default
};

// Map Configuration
module.exports.initialize = function () {

  if ($('.geographic-map').length) {
    $('.geographic-map').each(function (idx, item) {
      var map_id = $(item).attr('id');
      var data = window[map_id];
      var feature, feature_old;
      var drawable = true;

      // var iconStyle = new ol.style.Style({
      //   text: new ol.style.Text({
      //     text: '\uf041',
      //     font: 'normal 18px FontAwesome',
      //     textBaseline: 'bottom',
      //     fill: new ol.style.Fill({
      //       color: 'red',
      //     })
      //   })
      // });
      var iconStyle;

      if ($(item).data('icon-path') !== undefined) {
        iconStyle = new ol.style.Style({
          image: new ol.style.Icon({
            anchor: [16, 32],
            anchorXUnits: 'pixels',
            anchorYUnits: 'pixels',
            src: $(item).data('icon-path')
          })
        });
      } else {
        iconStyle = new ol.style.Style({
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

      redIconStyle = new ol.style.Style({
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

      greenIconStyle = new ol.style.Style({
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

      var map = new ol.Map({
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

          $('.form-element.object.' + address_key).find('.form-element').find('input').each((index, elem) => {
            address[elem.name.get_key()] = elem.value;
          });

          $.getJSON('/places/geocode_address/', address).done(data => {
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
          }).fail((jqxhr, textStatus, error) => {
            console.log(textStatus + ', ' + error);
          }).always(() => {
            $(event.currentTarget).find('i.fa').remove();
          });
        });
      }

      if (data.type == 'Point' && feature !== undefined) {
        map.getView().setCenter(feature.getGeometry().getCoordinates());
      } else if (data.type == 'LineString') {
        map.getView().fit(feature.getGeometry());
      } else {
        var default_position = $(item).data('default-position');
        if (default_position !== undefined && default_position.longitude !== undefined && default_position.latitude !== undefined) {
          var newCoords = new ol.geom.Point([default_position.longitude, default_position.latitude]).transform('EPSG:4326', 'EPSG:3857');
          map.getView().setCenter(newCoords.getCoordinates());
        }
        if (default_position !== undefined && default_position.zoom !== undefined) map.getView().setZoom(default_position.zoom);
      }
    });
  }

}

function getLatLon(coords) {
  return ol.proj.transform(coords, 'EPSG:3857', 'EPSG:4326');
}

function setNewCoordinates(container, map, feature) {
  setCoordinates(container, feature.getGeometry().getCoordinates());
  setHiddenFieldValue(container, feature.getGeometry().getCoordinates());
  map.getView().setCenter(feature.getGeometry().getCoordinates());
}

function setCoordinates(container, coords) {
  var latlon = getLatLon(coords);
  $(container).parent('.geographic').siblings('.map-info').first().find('.longitude input').val(latlon[0]);
  $(container).parent('.geographic').siblings('.map-info').first().find('.latitude input').val(latlon[1]);
}

function setHiddenFieldValue(container, coords) {
  var latlon = getLatLon(coords);
  $(container).parent('.geographic').siblings('.location-data').first().val('POINT (' + latlon[0] + ' ' + latlon[1] + ')');
}
