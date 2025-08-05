# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module GeneratedTranslation
        def upsert_generated_translations
          return false unless DataCycleCore::Feature::GeneratedTranslation.allowed?(self) &&
                              DataCycleCore::Feature['Translate'].enabled?

          tlocales = DataCycleCore::Feature['Translate'].allowed_target_languages
          source_locale = first_available_locale
          glocales = I18n.available_locales.except(source_locale).intersection(tlocales.map(&:to_sym))
          success = true
          glocales.each do |locale|
            I18n.with_locale(locale) do
              next unless try(:generated_translation) || available_locales.exclude?(locale)

              base_locale = try(:generated_translation_source) || source_locale
              next unless base_locale

              translated_hash = generate_translated_datahash(base_locale)
              success &&= set_data_hash(data_hash: translated_hash)
            end
          end

          success
        end

        def generate_translated_datahash(source_locale, datahash = {})
          return {} unless (DataCycleCore::Feature::GeneratedTranslation.allowed?(self) || embedded?) &&
                           DataCycleCore::Feature['Translate'].enabled?

          allowed_keys = writable_property_names - computed_property_names - internal_property_names - dummy_property_names

          unless translations.in_locale(I18n.locale)&.updated_at&.>= translations.in_locale(source_locale)&.updated_at
            allowed_keys.intersection(translatable_string_property_names).each do |key|
              next if datahash.key?(key)
              datahash[key] = translate_property_value(key, source_locale)
            end
          end

          allowed_keys.intersection(untranslatable_embedded_property_names).each do |key|
            next if datahash.key?(key)
            datahash[key] = translate_embedded_properties(key, source_locale)
          end

          allowed_keys.intersection(translatable_embedded_property_names).each do |key|
            next if datahash.key?(key)
            datahash[key] = translate_embedded(key, source_locale)
          end

          datahash['generated_translation'] = true
          datahash['generated_translation_source'] = source_locale.to_s

          datahash
        end

        private

        def translate_embedded(key, source_locale)
          source_value = I18n.with_locale(source_locale) { try(key) }
          return if source_value.blank?

          existing = try(key)
          data = []

          source_value.each do |embedded|
            existing_embedded = existing.find { |e| e.external_key == embedded.id }
            datahash = { 'id' => existing_embedded&.id, 'template_name' => embedded.template_name }
            next data << datahash if existing_embedded&.translations&.in_locale(I18n.locale)&.updated_at&.>= embedded.translations.in_locale(source_locale)&.updated_at

            translated_embedded_hash = embedded.generate_translated_datahash(source_locale)

            data << datahash
              .merge({ 'external_key' => embedded.id })
              .merge(translated_embedded_hash)
          end

          data
        end

        def translate_embedded_properties(key, source_locale)
          source_value = I18n.with_locale(source_locale) { try(key) }
          return if source_value.blank?

          data = []

          source_value.each do |embedded|
            datahash = { 'id' => embedded.id, 'template_name' => embedded.template_name }
            next data << datahash if embedded.translations.in_locale(I18n.locale)&.updated_at&.>= embedded.translations.in_locale(source_locale)&.updated_at

            translated_embedded_hash = embedded.generate_translated_datahash(source_locale)

            data << datahash.merge(translated_embedded_hash)
          end

          data
        end

        def translate_property_value(key, source_locale)
          source_value = I18n.with_locale(source_locale) { try(key) }
          return if source_value.blank?

          endpoint = DataCycleCore::Feature['Translate'].endpoint
          data = endpoint.translate({
            'text' => source_value.to_s,
            'source_locale' => source_locale.to_s,
            'target_locale' => I18n.locale.to_s
          })
          endpoint.parse_translated(data)
        end
      end
    end
  end
end
