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
        puts("[done] ... looks good (Duration: #{(Time.zone.now - before_import).round} sec)")
      else
        exit(-1)
      end

      tmp = Time.zone.now
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
        puts("[done] ... looks good (Duration: #{(Time.zone.now - tmp).round} sec)")
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

    desc 'Auto tag all untagged images'
    task auto_tagging: [:environment] do
      abort('Feature AutoTagging has to be enabled!') unless Datacycle::Feature::AutoTagging.enabled?
      config = Datacycle::Feature::AutoTagging.configuration
      abort('Feature AutoTagging has to be configured!') if config.blank?
      abort('Feature AutoTagging has to be configured with a valid tree_label!') if config.dig(:tree_label).blank?
      tree_label = DataCycleCore::ClassificationTreeLabel.create_with(internal: true).find_or_create_by!(name: config.dig(:tree_label)) do |item|
        item.visibility = ['show']
      end

      template_names = ['Bild', 'ImageObject']
      classification_tree_label_id = tree_label.id

      query = <<-SQL.squish
          "things"."content_type" != 'embedded'
          AND "things"."template_name" IN ('#{template_names.join("', '")}')
          AND NOT (
            EXISTS (
              SELECT 1
              FROM collected_classification_contents
              WHERE collected_classification_contents.thing_id = things.id
              AND collected_classification_contents.classification_tree_label_id IN ('#{classification_tree_label_id}')
            )
          )
      SQL

      images = DataCycleCore::Thing.where(query)

      total_items = images.count

      start_time = Time.zone.now
      count = 0

      queue = DataCycleCore::WorkerPool.new(ActiveRecord::Base.connection_pool.size - 1)
      progress = ProgressBar.create(total: total_items, format: '%t |%w>%i| %a - %c/%C', title: 'AutoTagging')

      puts "Auto tagging #{total_items} Things  with template names #{template_names.join(', ')}, without tree label: #{tree_label.name}"

      queue.append do
        images.find_each do |image|
          # puts "Auto tagging image: #{image.id}"
          progress.increment
          success = image.auto_tag
          count += 1 if success
        end
      end

      queue.wait!

      puts "AutoTagging finished (Duration: #{(Time.zone.now - start_time).round} sec)"
      puts "AutoTagging successful for #{count} of #{total_items} images"
    end
  end
end
