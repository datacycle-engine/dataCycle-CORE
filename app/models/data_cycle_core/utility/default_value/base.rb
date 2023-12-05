# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Base
        class << self
          def default_values(key, data_hash, content, current_user = nil, force = false)
            return unless DataCycleCore::DataHashService.blank?(data_hash[key])

            properties = content.properties_for(key)&.with_indifferent_access

            return if properties.blank?

            return if properties['default_value'].is_a?(::Hash) && properties.dig('default_value', 'condition').present? && !properties.dig('default_value', 'condition').all? { |k, v| send("condition_#{k}", current_user, v, content) }

            if properties['default_value'].is_a?(::String) && properties['type'] == 'classification'
              method_name = DataCycleCore::Utility::DefaultValue::Classification.method(:by_name)
            elsif properties['default_value'].is_a?(::String) || properties['default_value'].is_a?(::Numeric)
              data_hash[key] = properties['default_value']
              return
            else
              method_name = DataCycleCore::ModuleService
                .load_module(properties.dig('default_value', 'module').classify, 'Utility::DefaultValue')
                .method(properties.dig('default_value', 'method'))
            end

            property_parameters = Array.wrap(properties&.dig('default_value', 'parameters')).intersection(content.property_names) if properties['default_value'].is_a?(::Hash)

            default_value_hash = data_hash.dc_deep_dup

            return if skip_default_value?(key, default_value_hash, content, property_parameters, current_user, false, force)

            data_hash[key] = method_name.call(
              property_parameters: property_parameters&.index_with { |v| default_value_hash[v] },
              key:,
              data_hash: default_value_hash,
              content:,
              property_definition: properties,
              current_user:
            )
          end

          private

          def condition_user(user, config, _content)
            user&.is_rank?(config['rank'].to_i) if config&.dig('rank').present?
          end

          def condition_except_content_type(_user, config, content)
            content.content_type != config
          end

          def condition_schema_key_present(_user, config, content)
            content.schema.key?(config)
          end

          def skip_default_value?(key, data_hash, content, property_parameters, user, checked = false, force = false)
            return false if property_parameters.blank?

            missing_keys = property_parameters.difference(data_hash.slice(*property_parameters).keys)

            return false if missing_keys.blank?
            return true if checked && missing_keys.present?
            return true if !force && missing_keys.size == property_parameters.size && missing_keys.difference(content.default_value_property_names).present?

            missing_keys.intersection(content.default_value_property_names).each do |missing_default_key|
              default_values(missing_default_key, data_hash, content, user, force)
            end

            missing_keys.difference(content.default_value_property_names).each do |missing_key|
              data_hash[missing_key] = content.attribute_to_h(missing_key)
            end

            skip_default_value?(key, data_hash, content, property_parameters, user, true, force)
          end
        end
      end
    end
  end
end
