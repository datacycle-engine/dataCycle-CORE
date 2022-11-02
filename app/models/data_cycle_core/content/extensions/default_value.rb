# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module DefaultValue
        def add_default_values(data_hash:, current_user: nil, new_content: false, force: false, partial: false, keys: nil)
          default_value_keys = Array.wrap(keys.presence || default_value_property_names)

          # BUG: if attribute_blank? is used on content in new language, translated_locales will include the new language after this method call
          if new_content || force
            default_value_keys = default_value_keys.select { |k| attribute_blank?(data_hash, k) }
          elsif !partial && translated_locales.presence&.exclude?(I18n.locale)
            default_value_keys = default_value_keys.select { |k| attribute_blank?(data_hash, k) }.intersection(translatable_property_names)
          else
            default_value_keys = default_value_keys.select { |k| attribute_blank?(data_hash, k) }.intersection(data_hash.keys)
          end

          return data_hash if default_value_keys.blank?

          default_value_keys.each do |property_name|
            DataCycleCore::Utility::DefaultValue::Base.default_values(property_name, data_hash, self, current_user, force)
          end

          data_hash
        end

        def default_value(key, user, data_hash = {})
          return unless default_value_property_names.include?(key)

          DataCycleCore::Utility::DefaultValue::Base.default_values(key, data_hash, self, user)

          value = data_hash[key]

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
