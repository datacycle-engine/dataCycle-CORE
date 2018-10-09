# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :refactor do
    desc 'migrate all content_tables to things'
    task migrate_content_to_things: :environment do
      puts 'migrating all content_tables to things'

      puts '==> STAGE 1 - ORGANIZATIONS <=='
      Rake::Task['data_cycle_core:refactor:migrate_organizations_to_things'].invoke

      puts '==> STAGE 2 - PERSONS <=='
      Rake::Task['data_cycle_core:refactor:migrate_persons_to_things'].invoke

      puts '==> BONUS STAGE <=='
      Rake::Task['data_cycle_core:refactor:migrate_all_templates'].invoke
    end

    desc 'migrate organizations - executes all migration tasks'
    task migrate_organizations_to_things: :environment do
      temp = Time.zone.now
      puts 'MIGRATE DATA FOR'
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

      DataCycleCore::Search.where(content_data_type: 'DataCycleCore::Organization').update_all(content_data_type: 'DataCycleCore::Thing')
      DataCycleCore::WatchListDataHash.where(hashable_type: 'DataCycleCore::Organization').update_all(hashable_type: 'DataCycleCore::Thing')
      DataCycleCore::Subscription.where(subscribable_type: 'DataCycleCore::Organization').update_all(subscribable_type: 'DataCycleCore::Thing')
      DataCycleCore::DataLink.where(item_type: 'DataCycleCore::Organization').update_all(item_type: 'DataCycleCore::Thing')

      puts 'migrate data'
      puts '--> things'
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

      puts '--> thing_translations'
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
          content ->> 'legal_name',
          description,
          created_at, updated_at
        FROM organization_translations
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      puts '--> thing_histories'
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
        FROM organization_histories
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      puts '--> thing_history_translations'
      sql = <<-SQL
        INSERT INTO thing_history_translations (
          thing_history_id, locale,
          content,
          name,
          description,
          history_valid,
          created_at, updated_at
        )
        SELECT
          organization_history_id, locale,
          content,
          content ->> 'legal_name',
          description,
          history_valid,
          created_at, updated_at
        FROM organization_history_translations
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      puts 'END'
      puts "--> MIGRATION COMPLETE #{(Time.zone.now - temp).round(3)}"
    end

    desc 'migrate persons - executes all migration tasks'
    task migrate_persons_to_things: :environment do
      temp = Time.zone.now
      puts 'MIGRATE DATA FOR'
      puts "BEGIN: (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

      puts 'update references'
      DataCycleCore::ContentContent.where(content_a_type: 'DataCycleCore::Person').update_all(content_a_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent.where(content_b_type: 'DataCycleCore::Person').update_all(content_b_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent::History.where(content_a_history_type: 'DataCycleCore::Person').update_all(content_a_history_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Person').update_all(content_b_history_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent::History.where(content_a_history_type: 'DataCycleCore::Person::History').update_all(content_a_history_type: 'DataCycleCore::Thing::History')
      DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Person::History').update_all(content_b_history_type: 'DataCycleCore::Thing::History')

      DataCycleCore::ClassificationContent.where(content_data_type: 'DataCycleCore::Person').update_all(content_data_type: 'DataCycleCore::Thing')
      DataCycleCore::ClassificationContent::History.where(content_data_history_type: 'DataCycleCore::Person::History').update_all(content_data_history_type: 'DataCycleCore::Thing::History')

      DataCycleCore::Search.where(content_data_type: 'DataCycleCore::Person').update_all(content_data_type: 'DataCycleCore::Thing')
      DataCycleCore::WatchListDataHash.where(hashable_type: 'DataCycleCore::Person').update_all(hashable_type: 'DataCycleCore::Thing')
      DataCycleCore::Subscription.where(subscribable_type: 'DataCycleCore::Person').update_all(subscribable_type: 'DataCycleCore::Thing')
      DataCycleCore::DataLink.where(item_type: 'DataCycleCore::Person').update_all(item_type: 'DataCycleCore::Thing')

      puts 'migrate data'
      puts '--> things'
      sql = <<-SQL
        INSERT INTO things (
          id, metadata,
          given_name, family_name,
          template_name, schema, template,
          internal_name,
          external_source_id, external_key,
          created_by, updated_by, deleted_by,
          seen_at, created_at, updated_at, deleted_at
        )
        SELECT
          id, metadata,
          given_name, family_name,
          template_name, schema, template,
          concat(given_name, ' ', family_name),
          external_source_id, external_key,
          created_by, updated_by, deleted_by,
          seen_at, created_at, updated_at, deleted_at
        FROM persons
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      puts '--> thing_translations'
      sql = <<-SQL
        INSERT INTO thing_translations (
          thing_id, locale,
          content,
          name, description,
          created_at, updated_at
        )
        SELECT
          person_id, locale,
          content,
          headline,
          description,
          created_at, updated_at
        FROM person_translations
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      puts '--> thing_histories'
      sql = <<-SQL
        INSERT INTO thing_histories (
          id, thing_id, metadata,
          given_name, family_name,
          template_name, schema, template,
          internal_name,
          external_source_id, external_key,
          created_by, updated_by, deleted_by,
          seen_at, created_at, updated_at, deleted_at
        )
        SELECT
          id, person_id, metadata,
          given_name, family_name,
          template_name, schema, template,
          concat(given_name, ' ', family_name),
          external_source_id, external_key,
          created_by, updated_by, deleted_by,
          seen_at, created_at, updated_at, deleted_at
        FROM person_histories
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      puts '--> thing_history_translations'
      sql = <<-SQL
        INSERT INTO thing_history_translations (
          thing_history_id, locale,
          content,
          name,
          description,
          history_valid,
          created_at, updated_at
        )
        SELECT
          person_history_id, locale,
          content,
          headline,
          description,
          history_valid,
          created_at, updated_at
        FROM person_history_translations
      SQL
      ActiveRecord::Base.connection.exec_query(sql)

      puts 'END'
      puts "--> MIGRATION COMPLETE #{(Time.zone.now - temp).round(3)}"
    end
  end
end
