# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :refactor do
    desc 'executes all migration tasks'
    task migrate_organizations_to_things: :environment do
      temp = Time.zone.now
      puts 'MIGRATE DATA'
      puts "BEGIN: (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

      puts 'update references'
      DataCycleCore::ContentContent.where(content_a_type: 'DataCycleCore::Organization').update_all(content_a_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent.where(content_b_type: 'DataCycleCore::Organization').update_all(content_b_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent::History.where(content_a_history_type: 'DataCycleCore::Organization').update_all(content_a_history_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Organization').update_all(content_b_history_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent::History.where(content_a_history_type: 'DataCycleCore::Organization::History').update_all(content_a_history_type: 'DataCycleCore::Thing::History')
      DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Organization::History').update_all(content_b_history_type: 'DataCycleCore::Thing::History')

      DataCycleCore::ClassificationContent.where(content_data_type: 'DataCycleCore::Organization').update_all(content_data_type: 'DataCycleCore::Thing')
      DataCycleCore::ClassificationContent::History.where(content_data_history_type: 'DataCycleCore::Organization::History').update_all(content_data_history_type: 'DataCycleCore::Thing::History')

      puts 'migrate data'

      puts 'END'
      puts "--> MIGRATION COMPLETE #{(Time.zone.now - temp).round(3)}"
    end
  end
end
