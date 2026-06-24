# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module ComputedValue
        extend ActiveSupport::Concern

        def update_computed_values(keys:)
          return if keys.blank?

          computed_keys = keys.intersection(computed_property_names)
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

        def update_computed_values_for_locale(keys:, locale: nil)
          I18n.with_locale(first_available_locale(locale)) do
            data_hash = {}
            calculate_computed_values(data_hash:, keys:, force: true)
            set_data_hash(data_hash:)
          end
        end

        private

        def add_computed_values(data_hash:, keys:, current_user: nil)
          return if keys.blank?

          inline_keys = inline_computed_property_names.intersection(keys)
          async_keys = async_computed_property_names.intersection(keys)

          calculate_computed_values(data_hash:, current_user:, keys: inline_keys) if inline_keys.present?

          return if async_keys.blank?

          update_computed_values_async(async_keys, I18n.locale)
        end

        def calculate_computed_values(keys:, data_hash: {}, current_user: nil, force: false)
          return if keys.blank?

          Array.wrap(keys).each do |computed_property|
            DataCycleCore::Utility::Compute::Base.compute_values(computed_property, data_hash, self, current_user, force)
          end
        end

        def update_computed_values_async(keys, language)
          return if keys.blank?

          DataCycleCore::UpdateAsyncComputedPropertiesJob.perform_later(id, keys, language)
        end
      end
    end
  end
end
