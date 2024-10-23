# frozen_string_literal: true

class DeleteEmptyFeratelTranslations < ActiveRecord::Migration[5.2]
  def up
    external = DataCycleCore::ExternalSystem.find_by("name ILIKE 'Feratel%'")
    return if external.blank?
    [:accommodations, :infrastructure_items, :events].each do |collection_name|
      external.query(collection_name) do |mongo_collection|
        mongo_collection.where({ 'dump.de.deleted_at': { '$exists' => false } }).find_all do |item|
          item.dump.each_key do |locale|
            next if locale == 'de'
            next if item.dump[locale].blank?
            next if item.dump[locale]['deleted_at'].blank?
            next unless item.dump[locale]['delete_reason'] == 'Datamigration --> not german, has no <Descriptions> attribute --> not translated!'

            I18n.with_locale(locale) do
              thing = DataCycleCore::Thing.find_by(external_source_id: external.id, external_key: item.external_id)
              next if thing.blank?
              thing.destroy_content(save_history: false, destroy_locale: true)
            end
          end
        end
      end
    end
  end
end
