# frozen_string_literal: true

require 'rake_helpers/shell_helper'

namespace :dc do
  namespace :local_dev do
    # RAILS_ENV=development rake dc:local_dev:init
    desc 'init new lokal project'
    task init: :environment do
      Rake::Task['db:create'].invoke
      Rake::Task['db:create'].reenable

      Rake::Task['db:migrate'].invoke
      Rake::Task['db:migrate'].reenable

      Rake::Task['db:seed'].invoke
      Rake::Task['db:seed'].reenable

      Rake::Task['data_cycle_core:update:import_classifications'].invoke
      Rake::Task['data_cycle_core:update:import_classifications'].reenable

      Rake::Task['dc:external_systems:import'].invoke
      Rake::Task['dc:external_systems:import'].reenable

      Rake::Task['dc:templates:import'].invoke
      Rake::Task['dc:templates:import'].reenable
    end

    desc 'translate I18n locale files'
    task :translate_i18n, [:new_locale, :file_names] => :environment do |_, args|
      abort('MISSING_LOCALE') if args.new_locale.blank?
      abort('TRANSLATE_FEATURE_DISABLED') unless DataCycleCore::Feature::Translate.enabled?

      new_locale = args.new_locale
      file_names = Regexp.new(args.file_names, 'i') if args.file_names.present?
      file_paths = Dir[DataCycleCore::Engine.root.join('config', 'locales', '{*.de,de}.yml')]
      file_paths.concat(Dir[Rails.root.join('config', 'locales', '{*.de,de}.yml')])
      file_paths.select! { |p| file_names.match?(File.basename(p)) } if file_names.present?

      puts 'AUTOMATIC I18N TRANSLATION STARTED...'

      file_paths.each do |file_path|
        puts "TRANSLATING #{file_path}..."

        existing_translations = YAML.safe_load(File.open(file_path), permitted_classes: [Symbol])

        next if existing_translations.blank?

        existing_translations[new_locale] = existing_translations.delete('de')

        new_translations = existing_translations.dc_deep_transform_values do |value|
          next value unless value.is_a?(String)

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
