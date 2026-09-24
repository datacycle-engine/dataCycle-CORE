# frozen_string_literal: true

delete_concepts = <<-SQL
  DELETE FROM concept_links;
  DELETE FROM concepts;
  DELETE FROM concept_schemes;
SQL

delete_secondary_data = <<-SQL
  DELETE FROM watch_list_data_hashes;
  DELETE FROM watch_lists;
  DELETE FROM subscriptions;
  DELETE FROM data_links;
SQL

delete_contents = <<-SQL
  DELETE FROM things;
  DELETE FROM thing_translations;

  DELETE FROM content_contents;

  DELETE FROM concept_contents;
  DELETE FROM searches;
SQL

delete_assets = <<-SQL
  DELETE FROM assets;
  DELETE FROM asset_contents;
SQL

# Redmine #41458: a deleted concept lives on in the history tables, so that is where the rows a
# soft delete used to leave behind are now.
delete_concept_histories = <<-SQL
  DELETE FROM concept_link_histories;
  DELETE FROM concept_histories;
  DELETE FROM concept_scheme_histories;
SQL

namespace :data_cycle_core do
  namespace :clear do
    desc 'Remove all data except for configuration data like users'
    task all: :environment do
      ActiveRecord::Base.connection.execute(delete_concepts)
      ActiveRecord::Base.connection.execute(delete_secondary_data)
      ActiveRecord::Base.connection.execute(delete_contents)
      ActiveRecord::Base.connection.execute(delete_content_histories)
      ActiveRecord::Base.connection.execute(delete_assets)
    end

    desc 'Remove all contents related data like creative works and places (does not remove classifications)'
    task contents: :environment do
      ActiveRecord::Base.connection.execute(delete_secondary_data)
      ActiveRecord::Base.connection.execute(delete_contents)
      ActiveRecord::Base.connection.execute(delete_content_histories)
    end

    desc 'Remove all assets and asset relations'
    task assets: :environment do
      ActiveRecord::Base.connection.execute(delete_assets)
    end

    desc 'Remove the history of all content data'
    task :history, [:keep_internal, :imported_only] => [:environment] do |_, args|
      keep_internal = args.keep_internal.to_s == 'true'
      imported_only = args.imported_only.to_s == 'true'
      histories_to_delete = DataCycleCore::Thing::History.where(deleted_at: nil, version_name: nil)
      histories_to_delete = histories_to_delete.where.not(external_source_id: nil) if imported_only
      histories_to_delete = histories_to_delete.where(updated_by: nil) if keep_internal
      histories_to_delete_sql = histories_to_delete.select(:id)

      DataCycleCore::ContentContent::History.where(content_a_history_id: histories_to_delete_sql).delete_all
      DataCycleCore::ConceptContent::History.where(content_data_history_id: histories_to_delete_sql).delete_all
      DataCycleCore::Schedule::History.where(thing_history_id: histories_to_delete_sql).delete_all
      DataCycleCore::Thing::History::Translation.where(thing_history_id: histories_to_delete_sql).delete_all

      histories_to_delete.delete_all

      Rake::Task['db:maintenance:vacuum'].invoke
    end

    desc 'Remove the history of every deleted concept, scheme and link'
    task classifications: :environment do
      ActiveRecord::Base.connection.execute(delete_concept_histories)
    end

    desc 'Remove activities except type donwload older than 3 months [include_downloads=false, max_age=90]. Max age is in days.'
    task :activities, [:include_downloads, :max_age] => [:environment] do |_, args|
      max_age = (args.max_age&.to_i&.days || 3.months).ago
      include_downloads = args.include_downloads.to_s == 'true'

      persistent_activities = DataCycleCore.persistent_activities
      persistent_activities -= ['downloads'] if include_downloads

      raw_query = <<~SQL.squish
        DELETE
        FROM activities
        WHERE activities.created_at < :max_age
      SQL

      raw_query += ' AND activities.activity_type NOT IN (:persistent_activities)' if persistent_activities.present?
      sanitized_sql = ActiveRecord::Base.send(
        :sanitize_sql_for_conditions,
        [raw_query, { max_age:, persistent_activities: }]
      )

      ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
        ActiveRecord::Base.connection.exec_query(sanitized_sql)
      end

      Rake::Task['db:maintenance:vacuum'].invoke(true, 'activities')
      Rake::Task['db:maintenance:vacuum'].reenable
    end
  end
end
