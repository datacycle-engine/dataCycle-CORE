# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Base
        class << self
          def default_values(key, properties, data_hash, content, current_user = nil)
            # return value if it is already set
            existing_value = data_hash[key] || content.try(key)
            return existing_value unless DataCycleCore::DataHashService.blank?(existing_value)

            properties = properties&.with_indifferent_access
            return if properties['default_value'].is_a?(::Hash) && properties.dig('default_value', 'condition').present? && !properties.dig('default_value', 'condition').all? { |k, v| send("condition_#{k}", current_user, v) }

            if properties['default_value'].is_a?(::String) && properties['type'] == 'classification'
              method_name = DataCycleCore::Utility::DefaultValue::Classification.method(:by_name)
            elsif properties['default_value'].is_a?(::String)
              return properties['default_value']
            else
              module_name = properties.dig('default_value', 'module').classify.safe_constantize
              method_name = module_name.method(properties.dig('default_value', 'method'))
            end

            property_parameters = properties.dig('default_value', 'parameters')&.values&.map { |value| data_hash.dig(value) } if properties['default_value'].is_a?(Hash)

            method_name.try(:call, **{ property_parameters: property_parameters, key: key, data_hash: data_hash, content: content, property_definition: properties, current_user: current_user })
          end

          private

          def condition_user(user, config)
            user&.is_rank?(config['rank'].to_i) if config&.dig('rank').present?
          end
        end
      end
    end
  end
end
