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
      Rake::Task['dc:templates:import'].invoke
    end

    desc 'translate I18n locale files'
    task :translate_i18n, [:new_locale, :source_file_paths] => :environment do |_, args|
      abort('MISSING_LOCALE') if args.new_locale.blank?
      abort('TRANSLATE_FEATURE_DISABLED') unless DataCycleCore::Feature::Translate.enabled?

      new_locale = args.new_locale
      source_file_paths = args.source_file_paths&.split('|')&.map(&:squish)

      file_paths = Dir[DataCycleCore::Engine.root.join('config', 'locales', '{*.de,de}.yml')]
      file_paths.concat(Dir[Rails.root.join('config', 'locales', '{*.de,de}.yml')])
      file_paths.select! { |p| p.in?(source_file_paths) } if source_file_paths.present?

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

        new_path = File.join(File.dirname(file_path), "deepl.#{File.basename(file_path).gsub('de.', "#{new_locale}.")}")

        File.write(new_path, new_translations.to_yaml)
      end

      puts 'AUTOMATIC I18N TRANSLATION FINISHED...'
    end
  end
end
