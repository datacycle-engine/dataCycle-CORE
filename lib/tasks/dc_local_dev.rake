# frozen_string_literal: true

require 'rake_helpers/shell_helper'

namespace :dc do
  namespace :local_dev do
    # RAILS_ENV=development rake dc:local_dev:init
    desc 'init new lokal project'
    task init: :environment do
      Rake::Task['db:create'].invoke
      Rake::Task['db:migrate'].invoke
      Rake::Task['db:seed'].invoke
      Rake::Task['data_cycle_core:update:import_classifications'].invoke
      Rake::Task['data_cycle_core:update:import_external_system_configs'].invoke
      Rake::Task['data_cycle_core:update:import_templates'].invoke
    end

    desc 'init env file'
    task :init_env, [:application_name, :domain] => :environment do |_, args|
      if args[:application_name].nil?
        puts 'Error: application_name not set!'
        exit(-1)
      end
      if args[:domain].nil?
        puts 'Error: domain not set!'
        exit(-1)
      end

      input = ShellHelper.prompt 'Please enter Postgres Password'

      if input.present?
        Rails.root.join('tmp', '.env').open('w') do |file|
          file << "POSTGRES_USER=#{args[:application_name]}\n"
          file << "POSTGRES_DATABASE=#{args[:application_name]}_production\n"
          file << "POSTGRES_PASSWORD=#{input}\n"
          file << "SECRET_KEY_BASE=#{SecureRandom.hex(64)}\n"
          file << "REDIS_SERVER=localhost\n"
          file << "REDIS_PORT=6379\n"
          file << "REDIS_CACHE_DATABASE=2\n"
          file << "REDIS_CABLE_DATABASE=10\n"
          file << "REDIS_CACHE_NAMESPACE=#{args[:application_name]}_production\n"

          file << "APP_HOST=#{args[:domain]}\n"
          file << "APP_PROTOCOL=http\n"

          file << "APPSIGNAL_APP_NAME=#{args[:domain]}\n"
        end
      end
    end

    desc 'translate I18n locale files'
    task :translate_i18n, [:new_locale, :source_files] => :environment do |_, args|
      abort('MISSING_LOCALE') if args.new_locale.blank?
      abort('TRANSLATE_FEATURE_DISABLED') unless DataCycleCore::Feature::Translate.enabled?

      new_locale = args.new_locale
      source_files = args.source_files&.split('|')&.map(&:squish)

      file_paths = Dir[DataCycleCore::Engine.root.join('config', 'locales', '{*.de,de}.yml')]
      file_paths.concat(Dir[Rails.root.join('config', 'locales', '{*.de,de}.yml')])

      file_paths.select! { |p| File.basename(p).in?(source_files) } if source_files.present?

      puts 'AUTOMATIC I18N TRANSLATION STARTED...'

      file_paths.each do |file_path|
        puts "TRANSLATING #{file_path}..."

        existing_translations = YAML.safe_load(File.open(file_path), [Symbol])

        next if existing_translations.blank?

        existing_translations[new_locale] = existing_translations.delete('de')

        new_translations = existing_translations.dc_deep_transform_values do |value|
          next value unless value.is_a?(::String)

          translated_value = DataCycleCore::Feature::Translate.translate_text({ 'text' => value, 'source_locale' => 'de', 'target_locale' => new_locale })

          if translated_value.try(:error).present?
            puts "ERROR: #{translated_value.try(:error)}"
            value
          else
            translated_value.dig('text')
          end

        rescue Faraday::Error => e
          puts "FARADAY ERROR: #{e.message}"
        end

        new_path = File.join(File.dirname(file_path), "deepl.#{File.basename(file_path).gsub('.de.', ".#{new_locale}.")}")

        File.write(new_path, new_translations.to_yaml)
      end

      puts 'AUTOMATIC I18N TRANSLATION FINISHED...'
    end
  end
end
