# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Base
        class << self
          def compute_values(key, data_hash, content, force)
            return if data_hash.key?(key)

            properties = content.properties_for(key)&.with_indifferent_access

            return if properties.blank?

            computed_parameters = Array.wrap(properties&.dig('compute', 'parameters'))

            return unless conditions_satisfied?(content, properties)
            return if skip_compute_value?(key, data_hash, content, computed_parameters, force)

            module_name = ('DataCycleCore::' + properties.dig('compute', 'module').classify).safe_constantize
            method_name = module_name.method(properties.dig('compute', 'method'))

            data_hash[key] = method_name.try(:call, **{
              computed_parameters: computed_parameters.index_with { |v| data_hash[v] },
              key: key,
              data_hash: data_hash,
              content: content,
              computed_definition: properties
            })
          end

          def conditions_satisfied?(content, properties)
            return true unless properties['compute'].key?('conditions')

            Array.wrap(properties.dig('compute', 'conditions')).compact_blank.each do |condition|
              return false unless condition_satisfied?(content, condition)
            end

            true
          end

          def condition_satisfied?(content, definition)
            expected_value = definition['value']

            value = case definition['type']
                    when 'external_source'
                      content&.external_source&.default_options&.dig(definition['name'])
                    when 'I18n'
                      I18n.send(definition['name'])
                    when 'content'
                      content.send(definition['name'])
                    else
                      raise 'Unknown type for validation'
                    end

            send(definition['method'], value, expected_value)
          end

          def skip_compute_value?(key, data_hash, content, computed_parameters, force, checked = false)
            return false if computed_parameters.blank?

            missing_keys = computed_parameters.difference(data_hash.slice(*computed_parameters).keys)

            return false if missing_keys.blank?
            return true if checked && missing_keys.present?
            return true if missing_keys.size == computed_parameters.size && missing_keys.difference(content.computed_property_names).present?

            missing_keys.intersection(content.computed_property_names).each do |missing_computed_key|
              compute_values(missing_computed_key, data_hash, content, force)
            end

            data_hash.merge!(content.get_data_hash_partial(missing_keys.difference(content.computed_property_names)))

            skip_compute_value?(key, data_hash, content, computed_parameters, force, true)
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
