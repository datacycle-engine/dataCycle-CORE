# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Geo
        extend ActiveSupport::Concern

        def elevation_data?(key)
          return false unless respond_to?(key.attribute_name_from_key)

          value = send(key.attribute_name_from_key)
          return false unless value.respond_to?(:coordinates)

          coords_with_elevation = lambda { |coords|
            next false unless coords.is_a?(::Array)

            coords.first.is_a?(::Array) ? coords.any?(coords_with_elevation) : coords[2].to_f.positive?
          }

          coords_with_elevation.call(value.coordinates)
        end
      end
    end
  end
end
