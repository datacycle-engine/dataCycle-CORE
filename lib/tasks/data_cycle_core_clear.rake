# frozen_string_literal: true

delete_classifications = <<-EOS
  DELETE FROM classifications;
  DELETE FROM classification_groups;
  DELETE FROM classification_aliases;
  DELETE FROM classification_trees;
  DELETE FROM classification_tree_labels;
EOS

delete_secondary_data = <<-EOS
  DELETE FROM watch_list_data_hashes;
  DELETE FROM watch_lists;
  DELETE FROM subscriptions;
  DELETE FROM data_links;
EOS

delete_contents = <<-EOS
  DELETE FROM things;
  DELETE FROM thing_translations;

  DELETE FROM content_contents;

  DELETE FROM classification_contents;
  DELETE FROM searches;
EOS

delete_assets = <<-EOS
  DELETE FROM assets;
  DELETE FROM asset_contents;
EOS

delete_soft_deleted_classifications = <<-EOS
  DELETE FROM classifications WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_groups WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_aliases WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_trees WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_tree_labels WHERE deleted_at IS NOT NULL;
EOS

namespace :data_cycle_core do
  namespace :clear do
    desc 'Remove all data except for configuration data like users'
    task all: :environment do
      ActiveRecord::Base.connection.execute(delete_classifications)
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
      DataCycleCore::ClassificationContent::History.where(content_data_history_id: histories_to_delete_sql).delete_all
      DataCycleCore::Schedule::History.where(thing_history_id: histories_to_delete_sql).delete_all
      DataCycleCore::Thing::History::Translation.where(thing_history_id: histories_to_delete_sql).delete_all

      histories_to_delete.delete_all

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:maintenance:vacuum"].invoke
    end

    desc 'Remove all soft-deleted classification data (paranoid)'
    task classifications: :environment do
      ActiveRecord::Base.connection.execute(delete_soft_deleted_classifications)
    end

    desc 'Remove activities except type donwload older than 3 monts [include_downloads=false, max_age=today-3months]'
    task :activities, [:include_downloads, :max_age] => [:environment] do |_, args|
      max_age = args.fetch(:max_age, nil) || 3.months.ago.to_date.to_s
      include_downloads = args.fetch(:include_downloads, false)

      persistent_activities = DataCycleCore.persistent_activities
      persistent_activities -= ['downloads'] if include_downloads.to_s == 'true'

      raw_query = <<-SQL.squish
        DELETE
        FROM activities
        WHERE activities.created_at < :max_age
      SQL

      raw_query += ' AND activities.activity_type NOT IN (:persistent_activities)' if persistent_activities.present?

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(
          :sanitize_sql_for_conditions,
          [
            raw_query,
            max_age: max_age,
            persistent_activities: persistent_activities
          ]
        )
      )
    end
  end
end
