# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module ComputedValue
        def add_computed_values(data_hash:, keys: nil, force: false)
          Array.wrap(keys.presence || computed_property_names).each do |computed_property|
            DataCycleCore::Utility::Compute::Base.compute_values(computed_property, data_hash, self, force)
          end
        end

        def update_computed_values(keys: nil)
          computed_keys = keys.present? ? keys.intersection(computed_property_names) : computed_property_names
          translated_computed = computed_keys.intersection(translatable_property_names)

          if translated_computed.present?
            available_locales.each do |locale|
              keys = locale == first_available_locale ? computed_keys : translated_computed
              update_computed_values_for_locale(keys:, locale:)
            end
          else
            update_computed_values_for_locale(keys: computed_keys)
          end
        end

        private

        def update_computed_values_for_locale(keys:, locale: first_available_locale)
          I18n.with_locale(locale) do
            data_hash = {}
            add_computed_values(data_hash:, keys:, force: true)
            set_data_hash(data_hash:, update_computed: false)
          end
        end
      end
    end
  end
end
