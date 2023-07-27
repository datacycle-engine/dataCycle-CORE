# frozen_string_literal: true

require 'rake_helpers/time_helper'

namespace :data_cycle_core do
  namespace :update do
    desc 'import all external_system configs'
    task import_external_system_configs: [:environment] do
      puts 'importing new external_system configs'
      errors = DataCycleCore::MasterData::ImportExternalSystems.import_all
      if errors.blank?
        puts '[done] ... looks good'
      else
        puts 'the following errors were encountered during import:'
        ap errors
      end
      puts "\n"
    end

    desc 'import classifications'
    task import_classifications: [:environment] do
      before_import = Time.zone.now
      puts 'importing new classification definitions'
      imported_classifications = DataCycleCore::MasterData::ImportClassifications.import_all
      if imported_classifications.size.positive?
        puts('[done] ... looks good')
      else
        exit(-1)
      end

      puts 'checking for unused <Inhaltstypen> classifications'
      data = DataCycleCore::MasterData::ImportClassifications.updated_classification_statistics(before_import)
      if data.present?
        puts "\nWARNING: the following classification_aliases are not updated:"
        puts 'name'.ljust(30) + ' | ' + 'last_seen'.ljust(38) + ' | ' + 'occurrence'
        puts '-' * 82
        data.each do |key, value|
          puts "#{key.to_s.ljust(30)} |  #{value[:seen_at].to_s(:long_usec).ljust(38)} | #{value[:count].to_s.rjust(7)}"
        end
      else
        puts('[done] ... looks good')
      end
      puts "\n"
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

    desc 'auto_tag all images (without Cloud Vision Tags)'
    task auto_tagging: [:environment] do
      abort('Feature AutoTagging has to be enabled!') unless DataCycleCore::Feature::AutoTagging.enabled?
      taggable_templates = ['Bild']
      tag_property = :cloud_vision_tags

      query = DataCycleCore::Thing.where(template_name: taggable_templates)
      max_items = query.count

      puts "AutoTagging all untagged Things with template #{taggable_templates} (#{max_items}) - (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
      DataCycleCore::ProgressBarService.for_shell(max_items) do |pb|
        query.find_each do |image|
          pb.inc
          next if image.send(tag_property).present?
          image.auto_tag
        end
      end
    end
  end
end
