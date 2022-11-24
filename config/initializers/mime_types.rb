# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
Mime::Type.register 'application/geo+json', :geojson, ['application/vnd.geo+json', 'application/geo+json']
Mime::Type.register 'application/x-protobuf', :pbf
