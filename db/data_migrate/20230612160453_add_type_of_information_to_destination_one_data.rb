# frozen_string_literal: true

class AddTypeOfInformationToDestinationOneData < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    es = DataCycleCore::ExternalSystem.find_by(identifier: 'destination_one')
    return if es.blank?

    description_classification = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Informationstypen', 'description')
    text_classification = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Informationstypen', 'text')

    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        # descriptions (teaser)
        ids = DataCycleCore::Thing.where(
          external_source_id: es.id,
          template_name: 'Ergänzende Information',
          name: I18n.t('import.destination_one.teaser', default: ['teaser'])
        ).pluck(:id)

        if ids.present?
          data_array = ids.map do |id|
            {
              content_data_id: id,
              classification_id: description_classification,
              relation: 'type_of_information'
            }
          end
          DataCycleCore::ClassificationContent.insert_all(
            data_array,
            unique_by: 'index_classification_contents_on_unique_constraint',
            returning: false
          )
        end

        # text (details)
        ids = DataCycleCore::Thing.where(
          external_source_id: es.id,
          template_name: 'Ergänzende Information',
          name: I18n.t('import.destination_one.details', default: ['details'])
        ).pluck(:id)

        if ids.present?
          data_array = ids.map do |id|
            {
              content_data_id: id,
              classification_id: text_classification,
              relation: 'type_of_information'
            }
          end
          DataCycleCore::ClassificationContent.insert_all(
            data_array,
            unique_by: 'index_classification_contents_on_unique_constraint',
            returning: false
          )
        end
      end
    end
  end

  def down
    # irreversible
  end
end
