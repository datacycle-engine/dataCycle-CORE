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
    task :vacuum, [:full, :reindex] => [:environment] do |_, args|
      full = args.fetch(:full, false)
      reindex = args.fetch(:reindex, false)

      options = []
      options << 'FULL' if full.to_s == 'true'
      options << 'ANALYZE'
      sql = "VACUUM (#{options.join(', ')});"

      ActiveRecord::Base.connection.execute(sql)

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

      ActiveRecord::Base.connection.execute <<-SQL.squish
        VACUUM (FULL, ANALYZE) classification_alias_paths, classification_alias_paths_transitive, collected_classification_contents;
      SQL
    end
  end
end
