# frozen_string_literal: true

namespace :dc do
  namespace :update do
    namespace :configs do
      desc 'import and update all classifications, external_sources, external_systems and templates'
      task :all, [:history] => :environment do |_, args|
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_classifications"].invoke
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_external_system_configs"].invoke
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_templates"].invoke
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:update_all_templates_sql"].invoke(args.fetch(:history, false))
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
  end
end
