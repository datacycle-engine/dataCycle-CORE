# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Base
        class << self
          def compute_values(key, data_hash, content, current_user = nil, force = false)
            return if data_hash.key?(key)

            properties = content.properties_for(key)&.with_indifferent_access

            return unless properties&.key?('compute')
            return unless conditions_satisfied?(content, properties, current_user)

            computed_parameters = parameter_keys(content, properties)
            computed_value_hash = data_hash.dc_deep_dup

            return if skip_compute_value?(key, computed_value_hash, content, computed_parameters, false, current_user, force)

            method_name = DataCycleCore::ModuleService
              .load_module(properties.dig('compute', 'module').classify, 'Utility::Compute')
              .method(properties.dig('compute', 'method'))

            data_hash[key] = method_name.call(
              computed_parameters: computed_parameters.index_with { |v| computed_value_hash[v] },
              key:,
              data_hash: computed_value_hash,
              content:,
              computed_definition: properties,
              current_user:
            )

            # keep fallback for imported computed values
            data_hash[key] = content.attribute_to_h(key) if DataCycleCore::DataHashService.blank?(data_hash[key]) && properties.dig('compute', 'fallback').to_s != 'false'
          end

          def parameter_keys(content, properties)
            if properties&.dig('compute', 'module')&.include?('ContentScore') && properties&.dig('compute', 'method') == 'calculate_from_feature'
              Array.wrap(content.try(:content_score_parameters)).map { |p| p.split('.').first }.uniq.intersection(content.property_names)
            else
              Array.wrap(properties&.dig('compute', 'parameters')).map { |p| p.split('.').first }.uniq.intersection(content.property_names)
            end
          end

          def conditions_satisfied?(content, properties, current_user)
            return true unless properties['compute'].key?('condition')

            Array.wrap(properties.dig('compute', 'condition')).compact_blank.each do |condition|
              return false unless condition_satisfied?(content, condition, current_user)
            end

            true
          end

          def condition_satisfied?(content, definition, current_user)
            expected_value = definition['value']

            value = case definition['type']
                    when 'external_source'
                      content&.external_source&.default_options&.dig(definition['name'])
                    when 'I18n'
                      I18n.send(definition['name'])
                    when 'content'
                      definition['name']&.split('.')&.inject(content, &:try)
                    when 'current_user'
                      allowed_methods = ['present?', 'nil?']
                      raise 'unknown method for current_user' unless allowed_methods.include?(definition['name'])
                      current_user.try(definition['name'])
                    else
                      raise 'Unknown type for validation'
                    end

            send(definition['method'], value, expected_value)
          end

          def load_missing_values(missing_keys, content, datahash, current_user = nil)
            missing_keys.each do |missing_key|
              if content.computed_property_names.include?(missing_key)
                compute_values(missing_key, datahash, content, current_user, true)
              else
                datahash[missing_key] = content.attribute_to_h(missing_key)
              end
            end
          end

          def skip_compute_value?(key, datahash, content, computed_parameters, checked = false, current_user = nil, force = false)
            return false if computed_parameters.blank?

            missing_keys = computed_parameters.difference(datahash.slice(*computed_parameters).keys)

            return false if missing_keys.blank?
            return true if checked && missing_keys.present?
            return true if !force && datahash.keys.intersection(content.resolved_computed_dependencies(key, datahash)).none?

            load_missing_values(missing_keys, content, datahash, current_user)

            skip_compute_value?(key, datahash, content, computed_parameters, true, current_user)
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
