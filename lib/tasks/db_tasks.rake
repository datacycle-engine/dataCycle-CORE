# frozen_string_literal: true

namespace :db do
  namespace :migrate do
    desc 'run data migrations'
    task with_data: :environment do
      data_paths = [
        Rails.root.join('db', 'data_migrate').to_s,
        DataCycleCore::Engine.root.join('db', 'data_migrate').to_s
      ]

      Rails.application.config.paths['db/migrate'].concat(data_paths)
      ActiveRecord::Migrator.migrations_paths.concat(data_paths)

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate"].invoke
    end

    desc 'check before migrations'
    task check: :environment do
      result = ActiveRecord::Base.connection.execute <<-SQL.squish
        WITH duplicate_external_classification AS (
          SELECT classifications.external_source_id,
            classifications.external_key,
            COUNT(*)
          FROM classifications
          WHERE classifications.external_source_id IS NOT NULL
            AND classifications.external_key IS NOT NULL
            AND classifications.deleted_at IS NULL
          GROUP BY classifications.external_source_id,
            classifications.external_key
          HAVING COUNT(*) > 1
        )
        SELECT classifications.id,
          classification_alias_paths.full_path_names,
          classification_contents.content_data_id
        FROM duplicate_external_classification
          JOIN classifications ON duplicate_external_classification.external_source_id = classifications.external_source_id
          AND duplicate_external_classification.external_key = classifications.external_key
          JOIN classification_groups ON classifications.id = classification_groups.classification_id
          JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
          LEFT OUTER JOIN classification_contents ON classification_contents.classification_id = classifications.id
        ORDER BY CHAR_LENGTH(classifications.external_key),
          classifications.external_key;
      SQL

      abort('duplicate external_classifications found!') if result.count.positive?
    end
  end

  namespace :rollback do
    desc 'run data migrations'
    task with_data: :environment do
      data_paths = [
        Rails.root.join('db', 'data_migrate').to_s,
        DataCycleCore::Engine.root.join('db', 'data_migrate').to_s
      ]

      Rails.application.config.paths['db/migrate'].concat(data_paths)
      ActiveRecord::Migrator.migrations_paths.concat(data_paths)

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:rollback"].invoke
    end
  end

  namespace :maintenance do
    desc 'run VACUUM (FULL) on DB, full(false|true)'
    task :vacuum, [:full, :reindex, :table_names] => [:environment] do |_, args|
      full = args.fetch(:full, false)
      reindex = args.fetch(:reindex, false)
      table_names = args.fetch(:table_names, nil).to_s.split('|')

      options = []
      options << 'FULL' if full.to_s == 'true'
      options << 'ANALYZE'
      sql = "VACUUM (#{options.join(', ')}) #{table_names.join(', ')}"

      ActiveRecord::Base.connection.execute("#{sql.squish};")
      ActiveRecord::Base.connection.execute('VACUUM (ANALYZE);') if full.to_s == 'true' # fix visibility tables

      next if full.to_s == 'true' || reindex.to_s != 'true'

      DbHelper.with_config do |_host, _port, db, _user, _password|
        ActiveRecord::Base.connection.execute("REINDEX DATABASE \"#{db}\";")
      end
    end
  end

  namespace :configure do
    desc 'rebuild all tables concerning transitive classifications'
    task rebuild_transitive_tables: :environment do
      function_for_paths = DataCycleCore::Feature::TransitiveClassificationPath.enabled? ? 'generate_ca_paths_transitive' : 'generate_classification_alias_paths'

      ActiveRecord::Base.connection.execute <<-SQL.squish
        SELECT #{function_for_paths} (ARRAY_AGG(id)) FROM classification_aliases;
      SQL

      next if Rails.env.test?

      ActiveRecord::Base.connection.execute('VACUUM (FULL, ANALYZE) classification_alias_paths, classification_alias_paths_transitive, collected_classification_contents;')
      ActiveRecord::Base.connection.execute('VACUUM (ANALYZE) classification_alias_paths, classification_alias_paths_transitive, collected_classification_contents;')
    end

    desc 'rebuild content_content_links'
    task rebuild_content_content_links: :environment do
      ActiveRecord::Base.connection.execute <<-SQL.squish
        SELECT generate_content_content_links(ARRAY_AGG(id)) FROM content_contents;
      SQL

      next if Rails.env.test?

      ActiveRecord::Base.connection.execute('VACUUM (FULL, ANALYZE) content_content_links;')
      ActiveRecord::Base.connection.execute('VACUUM (ANALYZE) content_content_links;')
    end
  end
end
