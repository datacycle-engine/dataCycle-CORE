# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module BasicFunctions
          def self.underscore_keys(data_hash)
            data_hash.to_h.deep_transform_keys { |k| k.to_s.underscore }
          end

          def self.strip_all(data_hash)
            data_hash.to_h.deep_transform_values { |v| v.is_a?(::String) ? v.strip : v }
          end

          def self.select_keys(data, *keys)
            data.slice(*keys.flatten)
          end

          def self.compact(data_hash)
            data_hash.compact
          end

          def self.merge(data_hash, new_hash)
            data_hash.merge(new_hash)
          end

          def self.merge_array_values(data_hash, key, merge_key)
            data_hash[key] = Array(data_hash[key]) | Array(data_hash[merge_key])
            data_hash
          end

          def self.add_field(data_hash, name, function, condition_function = nil)
            return data_hash if condition_function.present? && !condition_function.call(data_hash)

            data_hash.merge({ name => function.call(data_hash) })
          end

          def self.location(data_hash)
            location = RGeo::Geographic.spherical_factory(srid: 4326).point(data_hash['longitude'].to_f, data_hash['latitude'].to_f) if data_hash['longitude'].present? && data_hash['latitude'].present? && !(data_hash['longitude'].zero? && data_hash['latitude'].zero?)
            data_hash.nil? ? { 'location' => location.presence } : data_hash.merge({ 'location' => location.presence })
          end

          def self.geom_from_binary(data_hash)
            return data_hash if data_hash&.dig('geom').blank?

            geom = data_hash['geom']
            geom = geom.data if geom.is_a?(BSON::Binary)
            factory = RGeo::Geographic.simple_mercator_factory(
              uses_lenient_assertions: true,
              srid: 4326,
              has_z_coordinate: true,
              wkt_parser: { support_wkt12: true },
              wkt_generator: { convert_case: :upper, tag_format: :wkt12 }
            )

            data_hash.merge({ 'geom' => RGeo::WKRep::WKBParser.new(factory).parse(geom) })
          end
        end
      end
    end
  end
end
