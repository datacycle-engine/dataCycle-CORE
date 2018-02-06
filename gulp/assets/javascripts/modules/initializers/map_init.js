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
    Fill: require('ol/style/fill').default
  },
  View: require('ol/view').default,
  extent: require('ol/extent').default
};

// Map Configuration
module.exports.initialize = function () {

  if ($('.geographic-map').length) {
    $('.geographic-map').each(function (idx, item) {
      var map_id = $(item).attr('id');

      var data = window[map_id];


      var feature;
      if (data.type == 'Point') {
        feature = new ol.Feature({
          geometry: new ol.geom.Point(data.points[0])
        });
      } else if (data.type == 'LineString') {
        feature = new ol.Feature({
          geometry: new ol.geom.LineString(data.points)
        });
      }
      feature.getGeometry().transform('EPSG:4326', 'EPSG:3857');

      var layerLines = new ol.layer.Vector({
        source: new ol.source.Vector({
          features: [feature]
        }),
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

      if (data.type == 'Point') {
        map.getView().setCenter(feature.getGeometry().getCoordinates());
      } else if (data.type == 'LineString') {
        map.getView().fit(feature.getGeometry());
      }
    });
  }

}
