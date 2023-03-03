# frozen_string_literal: true

require 'rake_helpers/parallel_helper'

namespace :dc do
  namespace :update do
    desc 'import and update all classifications, external_sources, external_systems and templates'
    task configs: :environment do
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_classifications"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_external_system_configs"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:templates:import"].invoke
    end

    namespace :classifications do
      require 'csv'
      require 'roo'

      desc 'import mappings from XLSX or CSV file'
      task :mappings_from_spreadsheet, [:file_path] => :environment do |_, args|
        abort('file_path missing!') if args.file_path.blank?

        errors = []
        pool = Concurrent::FixedThreadPool.new(ActiveRecord::Base.connection_pool.size - 1)
        futures = []
        imported = 0
        duplicates = 0
        file_paths = Dir[args.file_path]

        abort('no files found at this path!') if file_paths.blank?

        file_paths.each do |file_path|
          Roo::Spreadsheet.open(file_path).each_with_pagename do |_name, sheet|
            sheet.each do |row|
              next if row.blank?

              ca_path = row[0].to_s.strip
              mapped_ca_path = row[1].to_s.strip

              next unless ca_path.include?('>') && mapped_ca_path.include?('>')

              ParallelHelper.run_in_parallel(futures, pool) do
                ca = DataCycleCore::ClassificationAlias.custom_find_by_full_path(ca_path)

                if ca.nil?
                  errors << "classification_alias not found (#{File.basename(file_path)} => #{ca_path})"
                  print 'x'
                  next
                end

                if ca.create_mapping_for_path(mapped_ca_path).positive?
                  imported += 1
                  print('+')
                else
                  duplicates += 1
                  print('.')
                end
              rescue ActiveRecord::RecordNotFound
                errors << "mapped classification_alias not found (#{File.basename(file_path)} => #{mapped_ca_path})"
                print 'x'
              end
            end

            futures.each(&:wait!)
          end
        end

        puts
        puts errors.join("\n")
        puts "FINISHED IMPORTING MAPPINGS! (new: #{imported}, duplicates: #{duplicates}, errors: #{errors.size})"
      end

      desc 'import translations from XLSX or CSV file'
      task :translations_from_spreadsheet, [:locale, :file_path] => :environment do |_, args|
        abort('locale missing!') if args.locale.blank?
        abort('locale not enabled in this system!') if I18n.available_locales.exclude?(args.locale.to_sym)
        abort('file_path missing!') if args.file_path.blank?

        errors = []
        pool = Concurrent::FixedThreadPool.new(ActiveRecord::Base.connection_pool.size - 1)
        futures = []
        file_paths = Dir[args.file_path]

        abort('no files found at this path!') if file_paths.blank?

        file_paths.each do |file_path|
          Roo::Spreadsheet.open(file_path).each_with_pagename do |_name, sheet|
            sheet.each do |row|
              next if row.blank?

              ca_path = row[0].to_s.strip
              ca_translation = row[1].to_s.strip

              next unless ca_path.include?('>') && ca_translation.present?

              ParallelHelper.run_in_parallel(futures, pool) do
                ca = DataCycleCore::ClassificationAlias.custom_find_by_full_path(ca_path)

                if ca.nil?
                  errors << "classification_alias not found (#{ca_path})"
                  print 'x'
                  next
                end

                I18n.with_locale(args.locale) do
                  ca.prevent_webhooks = true
                  ca.update(name: ca_translation.squish)
                end

                print '.'
              rescue StandardError
                errors << "unkown error occurred (#{ca_path})"
                print 'x'
              end
            end

            futures.each(&:wait!)
          end
        end

        puts
        puts errors.join("\n")
        puts "FINISHED IMPORTING TRANSLATIONS! (#{errors.size} errors)"
      end
    end

    namespace :search do
      desc 'rebuild the searches table'
      task :rebuild, [:template_names] => :environment do |_, args|
        temp_time = Time.zone.now
        template_names = args.template_names&.split('|')&.map(&:squish)
        puts 'UPDATING SEARCH ENTRIES'

        query = DataCycleCore::Thing.where(template: true).where.not(content_type: 'embedded')
        query = query.where(template_name: template_names) if template_names.present?

        query.find_each do |template_object|
          strategy = DataCycleCore::Update::UpdateSearch
          DataCycleCore::Update::Update.new(type: DataCycleCore::Thing, template: template_object, strategy: strategy, transformation: nil)
        end

        clean_up_query = DataCycleCore::Search.where('searches.updated_at < ?', temp_time)
        clean_up_query = clean_up_query.where(data_type: template_names) if template_names.present?
        clean_up_count = clean_up_query.delete_all

        puts "REMOVED #{clean_up_count} orphaned entries."
      end
    end

    namespace :cache do
      desc 'invalidates cache for expired things'
      task :invalidate_expired, [:dry_run] => :environment do |_, args|
        dry_run = args.fetch(:dry_run, false)

        expired_items_filter = DataCycleCore::StoredFilter.create(
          name: 'expired things',
          user_id: DataCycleCore::User.find_by(email: 'admin@datacycle.at').id,
          language: ['de'],
          parameters: [{
            'c' => 'a',
            'm' => 'i',
            'n' => 'relative',
            'q' => 'relative',
            't' => 'inactive_things',
            'v' => {
              'from' => {
                'n' => '7',
                'mode' => 'm',
                'unit' => 'day'
              },
              'until' => {
                'n' => '0',
                'mode' => 'p',
                'unit' => 'day'
              }
            }
          }]
        )
        items = expired_items_filter.apply
        puts "Expired items found: #{items.count}"
        items.each do |item|
          item.invalidate_self_and_update_search unless dry_run
          puts "Expired item found: #{item.id}"
        end
        puts '###### DRY-RUN: No database changes made!' if dry_run
      end
    end

    desc 'create all dictionaries in postgresql'
    task dictionaries: :environment do
      present_dictionaries = Dir[Rails.root.join('config', 'configurations', 'ts_search', '*.ths')].sort
      file_names = present_dictionaries.map { |f| f.split('/').last.split('.').first }

      file_names.each do |dict|
        dict_language = dict.split('_').last

        ActiveRecord::Base.connection.exec_query("
          ALTER TEXT SEARCH CONFIGURATION #{dict_language}
             ALTER MAPPING FOR asciihword, asciiword, hword, word
             WITH #{dict_language}_stem;
        ")

        ActiveRecord::Base.connection.exec_query("
          DROP TEXT SEARCH DICTIONARY IF EXISTS #{dict};
        ")

        ActiveRecord::Base.connection.exec_query("
          CREATE TEXT SEARCH DICTIONARY #{dict} (
            TEMPLATE = thesaurus,
            DictFile = #{dict},
            Dictionary = pg_catalog.#{dict_language}_stem
          );
        ")
        ActiveRecord::Base.connection.exec_query("
          ALTER TEXT SEARCH CONFIGURATION #{dict_language}
             ALTER MAPPING FOR asciihword, asciiword, hword, word
             WITH #{dict}, #{dict_language}_stem;
        ")
      end
    end
  end

  desc 'run migrations, update all configs and run data_migrations'
  task update: :environment do
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate"].reenable
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update:configs"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update:configs"].reenable
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate:with_data"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate:with_data"].reenable
  end
end
