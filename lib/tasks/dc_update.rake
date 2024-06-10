# frozen_string_literal: true

namespace :dc do
  namespace :update do
    desc 'import and update all classifications, external_sources, external_systems and templates'
    task configs: :environment do
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:templates:import"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:templates:import"].reenable

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_classifications"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_classifications"].reenable

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:external_systems:import"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:external_systems:import"].reenable
    end

    namespace :search do
      desc 'rebuild the searches table'
      task :rebuild, [:template_names] => :environment do |_, args|
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:search:rebuild"].invoke(args.template_names)
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:search:rebuild"].reenable
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
      present_dictionaries = Dir[Rails.root.join('config', 'configurations', 'ts_search', '*.ths')]
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
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate:check"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate:check"].reenable
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate"].reenable
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update:configs"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update:configs"].reenable
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate:with_data"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate:with_data"].reenable
  end
end
