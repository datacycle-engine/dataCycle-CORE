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
      sql = <<-SQL
        INSERT INTO things (
          id, metadata,
          template_name, schema, template,
          internal_name,
          external_source_id, external_key,
          created_by, updated_by, deleted_by,
          seen_at, created_at, updated_at, deleted_at
        )
        SELECT
          id, metadata,
          template_name, schema, template,
          NULL,
          external_source_id, external_key,
          created_by, updated_by, deleted_by,
          seen_at, created_at, updated_at, deleted_at
        FROM organizations
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      sql = <<-SQL
        INSERT INTO thing_translations (
          thing_id, locale,
          content,
          name, description,
          created_at, updated_at
        )
        SELECT
          organization_id, locale,
          content,
          headline, description,
          created_at, updated_at
        FROM organization_translations
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      sql = <<-SQL
        INSERT INTO thing_histories (
          id, thing_id, metadata,
          template_name, schema, template,
          internal_name,
          external_source_id, external_key,
          created_by, updated_by, deleted_by,
          seen_at, created_at, updated_at, deleted_at
        )
        SELECT
          id, organization_id, metadata,
          template_name, schema, template,
          NULL,
          external_source_id, external_key,
          created_by, updated_by, deleted_by,
          seen_at, created_at, updated_at, deleted_at
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      sql = <<-SQL
        INSERT INTO thing_history_translation (
          thing_history_id, locale,
          content, name, description,
          history_valid,
          created_at, updated_at
        )
        FROM organization_history_translations
          organization_history_id, locale,
          content, headline, description,
          history_valid,
          created_at, updated_at
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      puts 'END'
      puts "--> MIGRATION COMPLETE #{(Time.zone.now - temp).round(3)}"
    end
  end
end
