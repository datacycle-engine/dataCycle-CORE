# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      # Provides virtual attribute methods for object properties
      module Object
        extend DataCycleCore::ContentHelper

        class << self
          # Used to generate a virtual attribute for the start location of a tour
          # based on the line geometry of the content.
          # This allows us to include a start location in the API response
          # without it being stored as a separate attribute in the database.
          # :virtual_start_location:
          #   :type: object
          #   :storage_location: value
          #   :visible: api
          #   :position:
          #     :before: start_location
          #   :api:
          #     :name: odta:startLocation
          #     :type: Place
          #   :virtual:
          #     :module: Object
          #     :method: tour_start_location
          #     :parameters:
          #       - line
          #   :properties:
          #     ...
          def tour_start_location(content:, virtual_definition:, **)
            line = content.try(:line)
            return if line.blank?

            line = line.first if line.is_a?(RGeo::Geographic::SphericalMultiLineStringImpl)
            return if line.blank?

            start_point = line.start_point
            return if start_point.blank?

            geo_hash = {
              'location_name' => 'startLocation',
              'latitude' => start_point.latitude,
              'longitude' => start_point.longitude
            }

            geo_hash['elevation'] = start_point.z unless start_point.z.zero?

            OpenStructHash.new(geo_hash, content, virtual_definition)
          end
        end
      end
    end
  end
end
