json.set! '@type', 'GeoCoordinates'
json.set! 'latitude', geoData.latitude if geoData.latitude && geoData.longitude
json.set! 'longitude', geoData.longitude if geoData.latitude && geoData.longitude
json.set! 'elevation', geoData.elevation if geoData.elevation
