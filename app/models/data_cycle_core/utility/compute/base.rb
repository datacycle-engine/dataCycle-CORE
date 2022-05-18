# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Base
        class << self
          def compute_values(key, data_hash, content, force)
            return if data_hash.key?(key)

            properties = content.properties_for(key)

            return if properties.blank?
            return if skip_compute_value?(key, data_hash, content, properties, force)

            module_name = ('DataCycleCore::' + properties.dig('compute', 'module').classify).safe_constantize
            method_name = module_name.method(properties.dig('compute', 'method'))

            data_hash[key] = method_name.try(:call, **{
              computed_parameters: Array.wrap(properties&.dig('compute', 'parameters')).index_with { |v| data_hash[v] },
              computed_options: properties.dig('compute', 'options') || {},
              key: key,
              data_hash: data_hash,
              content: content,
              computed_definition: properties
            })
          end

          def missing_keys(properties, data_hash)
            computed_parameters = Array.wrap(properties&.dig('compute', 'parameters'))

            computed_parameters.difference(data_hash.slice(*computed_parameters).keys)
          end

          def skip_compute_value?(key, data_hash, content, properties, force, checked = false)
            missing_keys = missing_keys(properties, data_hash)

            raise "computed_exception: some required parameters are missing in data_hash (content: #{content.id}, key: #{key}, data_hash_keys: #{data_hash.keys})" if checked && missing_keys.size != Array.wrap(properties&.dig('compute', 'parameters')).size

            return true if missing_keys.blank? || checked

            missing_keys.intersection(content.computed_property_names).each do |missing_key|
              compute_values(missing_key, data_hash, content, force)
            end

            # TODO: load values for missing_keys from content if above execption is raised

            skip_compute_value?(key, data_hash, content, properties, force, true)
          end

          def equals?(value_a, value_b)
            value_a == value_b
          end

          def exists?(value_a, _value_b)
            value_a.present?
          end
        end
      end
    end
  end
end
