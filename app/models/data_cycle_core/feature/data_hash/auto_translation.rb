# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module AutoTranslation
        def auto_translate
          return if about.blank?
        end

        # create/update translations
        def create_translations
          return if content_a.pluck(:template_name).include?('Übersetzung')

          additional_infos = load_translated_content

          template = DataCycleCore::Thing.find_by(template_name: 'Übersetzung', template: true)
          data_type = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'Übersetzung')

          translations_created = {}

          additional_infos.each do |classification, locale_data_hash|
            content = DataCycleCore::Thing.new
            content.metadata ||= {}
            content.schema = template.schema
            content.template_name = template.template_name
            content.external_source_id = external_source_id
            content.external_key = "#{classification}:#{external_key}"
            content.save! # need id to add linked_data

            translations_created[classification] = []
            description_type = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', classification)
            locale_data_hash.each do |locale, data_hash|
              I18n.with_locale(locale) do
                error = content.set_data_hash(
                  data_hash: {
                    'name' => data_hash[:name],
                    'description' => data_hash[:description],
                    'imported' => true,
                    'generated' => false,
                    'description_type' => [description_type],
                    'data_type' => [data_type],
                    'about' => [id]
                  },
                  prevent_history: true,
                  partial_update: true
                )
                translations_created[classification].push(locale) if error[:error].blank?
              end
              translations_created[classification] = translations_created[classification].presence
            end
          end
          translations_created.compact
        end

        def load_translated_content
          content_b.where("content_contents.relation_a = 'additional_information'").map { |info|
            classification = info.classifications&.detect { |i| i.primary_classification_alias.classification_tree_label.name == 'Externe Informationstypen' }
            locale = info.available_locales.first # additional_informations are not translatable!!
            I18n.with_locale(locale) do
              {
                classification: classification.name,
                locale => {
                  name: info.name,
                  description: info.description
                }
              }
            end
          }.group_by { |i| i.delete(:classification) }
            .map { |classification, data_array| { classification => data_array.inject(&:merge) } }
            .inject(&:merge)
        end

        def destroy_all_translated_content
          content_a.map do |i|
            byebug
            next unless i.template_name == 'Übersetzung'
            I18n.with_locale(i.available_locales.first || 'de') { i.destroy_content(save_history: false, destroy_locale: false) }
          end
        end
      end
    end
  end
end
