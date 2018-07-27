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
    Text: require('ol/style/text').default
  },
  View: require('ol/view').default,
  extent: require('ol/extent').default,
  interaction: {
    Draw: require('ol/interaction/draw').default,
    Modify: require('ol/interaction/modify').default,
    Snap: require('ol/interaction/snap').default,
  },
  proj: require('ol/proj').default
};

// Map Configuration
module.exports.initialize = function () {

  if ($('.geographic-map').length) {
    $('.geographic-map').each(function (idx, item) {
      var map_id = $(item).attr('id');
      var data = window[map_id];
      var feature;
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

      if (data.type == 'Point' && data.points[0].length > 0) {
        drawable = false;
        feature = new ol.Feature({
          geometry: new ol.geom.Point(data.points[0])
        });
        // feature.setStyle(iconStyle);
      } else if (data.type == 'LineString') {
        feature = new ol.Feature({
          geometry: new ol.geom.LineString(data.points)
        });
      }

      var options = {};
      if (feature !== undefined) {
        feature.getGeometry().transform('EPSG:4326', 'EPSG:3857');
        options = {
          features: [feature]
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
      }

      if (data.type == 'Point' && feature !== undefined) {
        map.getView().setCenter(feature.getGeometry().getCoordinates());
      } else if (data.type == 'LineString') {
        map.getView().fit(feature.getGeometry());
      } else {
        var newCoords = new ol.geom.Point([14.128417968749998, 47.41520280002081]).transform('EPSG:4326', 'EPSG:3857');
        console.log(newCoords);
        map.getView().setCenter(newCoords.getCoordinates());
        map.getView().setZoom(7);
      }
    });
  }

}

function getLatLon(coords) {
  return ol.proj.transform(coords, 'EPSG:3857', 'EPSG:4326');
}

function setCoordinates(container, coords) {
  var latlon = getLatLon(coords);
  $(container).siblings('.map-info').first().find('.map-location-data').text(latlon[0] + ', ' + latlon[1]);
}

function setHiddenFieldValue(container, coords) {
  var latlon = getLatLon(coords);
  $(container).parent('.geographic').siblings('.location-data').first().val('POINT (' + latlon[0] + ' ' + latlon[1] + ')');
}
