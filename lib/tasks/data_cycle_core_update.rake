# frozen_string_literal: true

require 'rake_helpers/time_helper'

namespace :data_cycle_core do
  namespace :update do
    desc 'import all external_system configs'
    task import_external_system_configs: [:environment] do
      puts 'importing new external_system configs'
      errors = DataCycleCore::MasterData::ImportExternalSystems.import_all
      if errors.blank?
        puts AmazingPrint::Colors.green('[done] ... looks good')
      else
        puts AmazingPrint::Colors.red('the following errors were encountered during import:')
        ap errors
      end
      puts "\n"
    end

    desc 'import classifications'
    task import_classifications: [:environment] do
      Rake::Task['dc:concepts:import'].invoke
      Rake::Task['dc:concepts:import'].reenable
    end

    desc 'delete history of a specific template_name'
    task :delete_history, [:template_name] => [:environment] do |_, args|
      template = DataCycleCore::ThingTemplate.find_by(template_name: args[:template_name])
      if template.nil?
        puts 'ERROR: template not found. The following templates are known to the system:'
        puts DataCycleCore::ThingTemplate.pluck(:template_name).sort
        exit(-1)
      end

      data_object = DataCycleCore::Thing::History.where(template_name: args[:template_name])
      total_items = data_object.count
      puts "DELETE history for: #{args[:template_name]} (#{total_items}) - (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
      index = 0

      data_object.find_each do |data_item|
        # progress_bar
        if total_items > 49
          if (index % 500).zero?
            fraction = (index / (total_items / 100.0)).round(0)
            fraction = 100 if fraction > 100
            print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
          end
        else
          fraction = (((index * 1.0) / total_items) * 100.0).round(0)
          fraction = 100 if fraction > 100
          print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
        end
        index += 1

        data_item.destroy_content
      end
      puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
    end
  end
end
