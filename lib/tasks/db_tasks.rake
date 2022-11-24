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
    desc 'rebuild collected_classification_content_relations according to configuration'
    task rebuild_ccc_relations: :environment do
      function_to_rebuild = DataCycleCore.transitive_classification_paths ? 'generate_collected_cl_content_relations_transitive' : 'generate_collected_classification_content_relations'

      ActiveRecord::Base.connection.execute <<-SQL.squish
        SELECT
          #{function_to_rebuild} (ARRAY_AGG(id), ARRAY[]::uuid[])
        FROM
          things
        WHERE
          TEMPLATE = FALSE;
      SQL
    end

    desc 'rebuild classification_alias_paths_transitive'
    task rebuild_cap_transitive: :environment do
      ActiveRecord::Base.connection.execute <<-SQL.squish
        SELECT generate_ca_paths_transitive(ARRAY_AGG(id)) FROM classification_aliases;
      SQL
    end

    desc 'rebuild classification_alias_paths'
    task rebuild_ca_paths: :environment do
      ActiveRecord::Base.connection.execute <<-SQL.squish
        SELECT generate_classification_alias_paths(ARRAY_AGG(id)) FROM classification_aliases;
      SQL
    end
  end
end
