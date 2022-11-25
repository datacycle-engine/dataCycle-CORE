# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module AutoTagging
        def auto_tag
          return unless thumbnail_url.present? || content_url.present?
          treshold = DataCycleCore.features.dig(:auto_tagging, :score) || 0.5
          tree_name = DataCycleCore.features.dig(:auto_tagging, :tree_label) || 'Cloud Vision - Tags'
          relation_name = DataCycleCore.features.dig(:auto_tagging, :relation_name) || 'cloud_vision_tags'
          external_source_name = DataCycleCore.features.dig(:auto_tagging, :external_source) || 'Google Cloud Vision'
          file_path = thumbnail_url || content_url

          require 'google/cloud/vision'
          require 'google/cloud/translate'

          external_source = DataCycleCore::ExternalSystem.find_by(name: external_source_name)
          image_annotator = Google::Cloud::Vision.image_annotator
          translation_service = Google::Cloud::Translate.translation_v2_service(project_id: external_source.credentials.dig('project_id'))

          response = image_annotator.label_detection(
            image: file_path,
            max_results: 30
          )

          tag_records = response.responses.first.label_annotations
            .map { |item| { description: item.description, score: item.score } }
            .select { |item| item.dig(:score) >= treshold }
            .map do |item|
              stored_alias = I18n.with_locale(:en) do
                DataCycleCore::ClassificationAlias
                  .for_tree(tree_name)
                  .find_by(
                    external_source_id: external_source.id,
                    name: item.dig(:description)
                  )
              end
              item_name =
                if stored_alias.present?
                  stored_alias.name
                else
                  translation_service.translate(item.dig(:description), to: 'de').text
                end
              item.merge({ name: item_name })
            end

          tags = tag_records&.map { |item| item.dig(:name) }
          utility_object = OpenStruct.new
          utility_object.external_source = external_source
          utility_object.options = {}

          tag_records.each do |item|
            external_key = item.dig(:name)
            [:de, :en].each do |lang|
              tag_name = lang == :de ? item.dig(:name) : item.dig(:description)
              I18n.with_locale(lang) do
                DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                  utility_object: utility_object,
                  classification_data: {
                    name: tag_name,
                    tree_name: tree_name,
                    external_key: external_key
                  }
                )
              end
            end
          end

          tag_ids = DataCycleCore::ClassificationAlias
            .for_tree(tree_name)
            .where(external_source_id: external_source.id, name: tags)
            .map { |item| item.classifications.first.id }

          set_classification_relation_ids(tag_ids, relation_name, tree_name, nil, true, false) # ids: tag_ids, relation_name: relation_name, _tree_label: tree_label, default_value: nil, not_translated: true, universal: false
          tag_ids
        end
      end
    end
  end
end
