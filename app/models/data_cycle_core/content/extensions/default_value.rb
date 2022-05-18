# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module DefaultValue
<<<<<<< HEAD
        def add_default_values(data_hash:, current_user: nil, new_content: false, force: false)
          if new_content || force
            props = properties_with_default_values.select { |k, _| attribute_blank?(data_hash, k) }
          elsif translated_locales.presence&.exclude?(I18n.locale)
=======
        def add_default_values(data_hash:, current_user: nil, new_content: false, force: false, partial: false)
          if new_content || force
            props = properties_with_default_values.select { |k, _| attribute_blank?(data_hash, k) }
          elsif !partial && translated_locales.presence&.exclude?(I18n.locale)
>>>>>>> old/develop
            props = properties_with_default_values.select { |k, _| attribute_blank?(data_hash, k) }.slice(*translatable_property_names)
          else
            props = properties_with_default_values.select { |k, _| attribute_blank?(data_hash, k) }.slice(*data_hash.keys)
          end

          return data_hash if props.blank?

          props.each do |property_name, property_definition|
            data_hash[property_name] = DataCycleCore::Utility::DefaultValue::Base.default_values(property_name, property_definition, data_hash, self, current_user)
          end

          data_hash
        end

        def default_value(key, user, data_hash = {})
          definition = properties_with_default_values[key]

          return if definition.blank?

          value = DataCycleCore::Utility::DefaultValue::Base.default_values(key, definition, data_hash, self, user)

          return if value.blank? && !value.is_a?(FalseClass)

          set_memoized_attribute(key, value)
        end

        def default_values_as_form_data(keys:, user:, data_hash: {})
          return_value = {}

          data_hash = data_hash.to_h if data_hash.is_a?(ActionController::Parameters)

          data_hash.each { |key, value| set_memoized_attribute(key, value) }

          keys&.each do |key|
            value = default_value(key.attribute_name_from_key, user, data_hash)

            next if DataCycleCore::DataHashService.blank?(value)

            attribute_key = "thing[datahash][#{key}]"
            attribute_key = "thing[translations][#{I18n.locale}][#{key}]" if translatable? && translatable_property?(key)
            attribute_key += '[]' if value.class.include?(::Enumerable)

            Array.wrap(value).each do |v|
              (return_value[key] ||= []).push({ name: attribute_key, value: v.try(:id) || v, text: v.try(:title) || v.try(:name) || v })
            end
          end

          return_value
        end
      end
    end
  end
end
