# frozen_string_literal: true

json.set! '@type', 'GeoCoordinates'
if geoData.location.try(:geometry_type) == RGeo::Feature::Point
  json.set! 'latitude', geoData.location.presence&.y if geoData.location.try(:geometry_type) == RGeo::Feature::Point
  json.set! 'longitude', geoData.location.presence&.x if geoData.location.try(:geometry_type) == RGeo::Feature::Point
elsif geoData.latitude.present? && geoData.longitude.present?
  json.set! 'latitude', geoData.try(:latitude)
  json.set! 'longitude', geoData.try(:longitude)
end
json.set! 'elevation', geoData.elevation if geoData.elevation.present? && geoData.elevation.nonzero?
