# frozen_string_literal: true

module Rails
  class DataMigrationGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('templates', __dir__)

    def create_migration_file
      timestamp = Time.zone.now.strftime('%Y%m%d%H%I%S')

      template 'migration.erb', "db/data_migrate/#{timestamp}_#{file_name}.rb"
    end

    def migration_class_name
      file_name.camelize
    end
  end
end
