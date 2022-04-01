# frozen_string_literal: true

class MarkFeratelMongoDataDeletedAllLanguages < ActiveRecord::Migration[5.2]
  def up
    external = DataCycleCore::ExternalSystem.find_by("name ILIKE 'Feratel%'")
    return if external.blank?
    [:accommodations, :infrastructure_items, :events].each do |collection_name|
      external.query(collection_name) do |mongo_collection|
        mongo_collection.where({ "dump.de.deleted_at": { '$exists' => true }, "dump.en.deleted_at": { '$exists' => false } }).find_all do |item|
          item.dump.each_key do |locale|
            next if locale == 'de'
            next if item.dump['de']['deleted_at'].blank?
            item.dump[locale]['deleted_at'] = item.dump['de']['deleted_at']
            item.dump[locale]['last_seen_before_delete'] = item.dump['de']['last_seen_before_delete'] if item.dump['de']['last_seen_before_delete'].present?
            item.dump[locale]['delete_reason'] = item.dump['de']['delete_reason'] if item.dump['de']['delete_reason'].present?
          end
          item.data_has_changed = false
          item.save!
        end
        mongo_collection.where({ "dump.de.deleted_at": { '$exists' => false }, "dump.en.deleted_at": { '$exists' => false } }).find_all do |item|
          item.dump.each_key do |locale|
            next if locale == 'de'
            next if item.dump[locale]['Descriptions'].present?
            item.dump[locale]['deleted_at'] = Time.zone.now
            item.dump[locale]['last_seen_before_delete'] = item.seen_at
            item.dump[locale]['delete_reason'] = 'Datamigration --> not german, has no <Descriptions> attribute --> not translated!'
          end
          item.data_has_changed = false
          item.save!
        end
      end
    end
  end
end
