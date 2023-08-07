# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module AutoTranslation
        # def after_save_data_hash(options)
        #   super
        #
        #   return if embedded?
        #   return unless DataCycleCore::Feature::AutoTranslation.allowed?(self)
        #   source_locale = DataCycleCore::Feature::AutoTranslation.configuration['source_lang'] || I18n.locale
        #   DataCycleCore::AutoTranslationJob.perform_later(id, source_locale)
        # end

        def create_update_translations
          additional_infos = load_translated_content
          return { 'error' => 'Nothing to translate' } if additional_infos.blank?
          template = ThingTemplate.find_by(template_name: 'Übersetzung')
          return { 'error' => 'Data Type not found!' } if template.blank?
          data_type = ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'Übersetzung')
          return { 'error' => 'Data Type not found (Classification)!' } if data_type.blank?

          translations_created = {}
          timestamp = Time.zone.now

          additional_infos.each do |classification, locale_data_hash|
            content = Thing.find_or_create_by(external_source_id: external_source_id, external_key: "#{classification}:#{external_key}") do |new_content|
              new_content.metadata ||= {}
              new_content.thing_template = template
              new_content.template_name = template.template_name
              new_content.external_source_id = external_source_id
            end
            translated_classification = content.translated_classification.presence&.pluck(:id) || ClassificationAlias.classifications_for_tree_with_name('Übersetzungstyp', 'Automatisch')

            translations_created[classification] = []
            description_type = ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', classification)

            locale_data_hash.each do |locale, data_hash|
              I18n.with_locale(locale) do
                next if content.translation_type.present? && content.translation_type != 'imported'
                next if data_hash[:name] == content.name && data_hash[:description] == content.description
                next unless content.set_data_hash(
                  data_hash: {
                    'name' => data_hash[:name],
                    'description' => data_hash[:description],
                    'translation_type' => 'imported',
                    'modified' => timestamp,
                    'description_type' => [description_type],
                    'translated_classification' => translated_classification,
                    'data_type' => [data_type],
                    'about' => [id]
                  },
                  prevent_history: true
                )
                translations_created[classification].push(locale)
              end
            end
            translations_created[classification] = translations_created[classification].presence&.sort
          end
          translations_created.compact
        end

        def create_update_auto_translations(source_locale = I18n.locale.to_s)
          source_locale = source_locale.to_s
          additional_translations = subject_of.where(template_name: 'Übersetzung')
          return { 'error' => 'Nothing to translate' } if additional_translations.blank?
          template = ThingTemplate.find_by(template_name: 'Übersetzung')
          return { 'error' => 'Data Type not found!' } if template.blank?
          data_type = ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'Übersetzung')
          return { 'error' => 'Data Type not found (Classification)!' } if data_type.blank?

          tlocales = (Feature::Translate.allowed_languages & I18n.available_locales.map(&:to_s))
          endpoint = Feature::Translate.endpoint

          translations_done = {}
          additional_translations.each do |content|
            next if content.blank?
            alocales = content.available_locales.map(&:to_s)
            next unless alocales.include?(source_locale)

            source_data = {}
            classification = nil
            translated_classification = content.translated_classification.presence&.pluck(:id) || ClassificationAlias.classifications_for_tree_with_name('Übersetzungstyp', 'Automatisch')
            I18n.with_locale(source_locale) do
              source_data = { 'name' => content.name, 'description' => content.description, 'modified' => content.modified }
              classification = content.description_type.first.name
              translations_done[classification] = []
            end

            tlocales.each do |target_locale|
              next if target_locale == source_locale
              I18n.with_locale(target_locale) do
                if content.translation_type.present?
                  next if content.translation_type != 'automatic'
                  next if source_data.dig('modified').blank? || content.modified >= source_data.dig('modified') # [TODO] check if source_data.dig('modified') should be allowed to be blank, and what should happen in this case
                end

                data = endpoint.translate({
                  'text' => source_data['description'],
                  'source_locale' => source_locale,
                  'target_locale' => target_locale
                })
                description = endpoint.parse_translated(data)
                next unless content.set_data_hash(
                  data_hash: {
                    'name' => classification,
                    'description' => description,
                    'translation_type' => 'automatic',
                    'translated_classification' => translated_classification,
                    'modified' => source_data.dig('modified'),
                    'source_locale' => source_locale,
                    'about' => [id]
                  },
                  prevent_history: true
                )
                translations_done[classification].push(target_locale.to_sym)
              end
            end
            translations_done[classification] = translations_done[classification].presence
          end
          translations_done.compact
        end

        def load_translated_content
          content_b.where("content_contents.relation_a = 'additional_information'").map { |info|
            classification = info.classifications&.detect { |i| i.primary_classification_alias.classification_tree_label.name == 'Externe Informationstypen' }
            locale = info.available_locales.first # additional_informations are not translatable!!
            I18n.with_locale(locale) do
              {
                classification: classification.name,
                locale => {
                  name: MasterData::DataConverter.string_to_string(info.name),
                  description: MasterData::DataConverter.string_to_string(info.description)
                }
              }
            end
          }.group_by { |i| i.delete(:classification) }
            .map { |classification, data_array| { classification => data_array.inject(&:merge) } }
            .inject(&:merge)
        end

        def destroy_auto_translations
          destroy_locales = translations.map { |i| i.locale if i.content['translation_type'] == 'manual' }.compact
          if (available_locales.map(&:to_s) - destroy_locales).present?
            destroy_locales.each do |locale|
              I18n.with_locale(locale) { destroy_content(destroy_locale: true) }
            end
            I18n.with_locale((available_locales.map(&:to_s) - destroy_locales).first) do
              set_data_hash(
                data_hash: {
                  translated_classification: ClassificationAlias.classifications_for_tree_with_name('Übersetzungstyp', 'Automatisch'),
                  translation_type: translation_type
                }
              )
            end
          else
            destroy_content
          end
        end

        def destroy_all_translated_content
          content_a.map do |i|
            next unless i.template_name == 'Übersetzung'
            I18n.with_locale(i.available_locales.first || 'de') { i.destroy_content(save_history: false, destroy_locale: false) }
          end
        end
      end
    end
  end
end
