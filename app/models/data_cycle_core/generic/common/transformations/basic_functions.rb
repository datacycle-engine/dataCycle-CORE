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
            data.select { |k, _| keys.flatten.include?(k) }
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
        end
      end
    end
  end
end
