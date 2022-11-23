# frozen_string_literal: true

namespace :dc do
  namespace :update do
    desc 'import and update all classifications, external_sources, external_systems and templates'
    task configs: :environment do
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_classifications"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_external_system_configs"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_templates"].invoke
    end

    namespace :classifications do
      require 'csv'

      desc 'append vacuum job to importers Queue'
      task mappings_from_csv: :environment do
        errors = []
        pool = Concurrent::FixedThreadPool.new(ActiveRecord::Base.connection_pool.size - 1)
        futures = []

        Dir[Rails.root.join('config', 'classification_mappings', '*.csv').to_s].each do |file_path|
          CSV.foreach(file_path, encoding: 'utf-8', quote_char: nil) do |data|
            next unless data&.[](0)&.include?('>') && data&.[](1)&.include?('>')

            futures << Concurrent::Promise.execute({ executor: pool }) do
              ActiveRecord::Base.connection_pool.with_connection do
                ca = DataCycleCore::ClassificationAlias.custom_find_by_full_path(data[0])

                if ca.nil?
                  errors << "classification_alias not found (#{data[0]})"
                  print 'x'
                  next
                end

                ca.create_mapping_for_path(data[1])
                print '.'
              rescue ActiveRecord::RecordNotFound
                errors << "mapped classification_alias not found (#{data[1]})"
                print 'x'
              end
            end
          end
        end

        futures.each(&:wait!)

        puts
        puts errors.join("\n")
        puts "FINISHED IMPORTING MAPPINGS! (#{errors.size} errors)"
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
end
