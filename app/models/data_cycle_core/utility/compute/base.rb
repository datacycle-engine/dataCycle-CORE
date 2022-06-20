# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Base
        class << self
          def compute_values(key, data_hash, content)
            return if data_hash.key?(key)

            properties = content.properties_for(key)&.with_indifferent_access

            return if properties.blank?

            computed_parameters = Array.wrap(properties&.dig('compute', 'parameters')).map { |p| p.split('.').first }.uniq.intersection(content.property_names)

            return unless conditions_satisfied?(content, properties)
            return if skip_compute_value?(key, data_hash, content, computed_parameters)

            module_name = ('DataCycleCore::' + properties.dig('compute', 'module').classify).safe_constantize
            method_name = module_name.method(properties.dig('compute', 'method'))

            data_hash[key] = method_name.try(:call, **{
              computed_parameters: computed_parameters.index_with { |v| data_hash[v] },
              key: key,
              data_hash: data_hash,
              content: content,
              computed_definition: properties
            })

            # keep fallback for imported computed values
            data_hash[key] = content.get_property_value(key, properties) if DataCycleCore::DataHashService.blank?(data_hash[key]) && properties.dig('compute', 'fallback').to_s != 'false'
          end

          def conditions_satisfied?(content, properties)
            return true unless properties['compute'].key?('condition')

            Array.wrap(properties.dig('compute', 'condition')).compact_blank.each do |condition|
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

          def load_missing_values(missing_keys, content, datahash)
            missing_keys.each do |missing_key|
              if content.computed_property_names.include?(missing_key)
                compute_values(missing_key, datahash, content)
              else
                datahash[missing_key] = content.property_value_for_set_datahash(missing_key)
              end
            end
          end

          def skip_compute_value?(key, datahash, content, computed_parameters, checked = false)
            return false if computed_parameters.blank?

            missing_keys = computed_parameters.difference(datahash.slice(*computed_parameters).keys)

            return false if missing_keys.blank?
            return true if checked && missing_keys.present?
            return true if missing_keys.size == computed_parameters.size && missing_keys.any? { |k| content.computed_property_names.exclude?(k) }

            load_missing_values(missing_keys, content, datahash)

            skip_compute_value?(key, datahash, content, computed_parameters, true)
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
