# frozen_string_literal: true

require 'rake_helpers/shell_helper'
require 'rake_helpers/cleanup_helper'

namespace :dc do
  namespace :clean_up do
    desc 'Remove all data from external_source'
    task :external_source_data, [:external_source_id, :dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false)
      external_source = DataCycleCore::ExternalSystem.find(args.fetch(:external_source_id))

      if external_source.nil?
        puts 'Error: No ExternalSystem found!'
        exit(-1)
      end

      external_contents = DataCycleCore::Thing.includes(:content_content_b).where(external_source_id: external_source.id).with_content_type('entity')
      initial_external_contents_count = external_contents.size
      puts "Found #{initial_external_contents_count} items"

      has_no_relation = DataCycleCore::Thing
        .includes(:content_content_b)
        .where(
          external_source_id: external_source.id,
          content_contents: {
            id: nil
          }
        ).with_content_type('entity')

      items_to_delete = has_no_relation.count
      puts "Items without relation : #{external_source.name} (#{items_to_delete}) - (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end

      index = 0

      has_no_relation.find_each do |data_item|
        ShellHelper.progress_bar(items_to_delete, index)
        index += 1

        data_item.destroy_content
      end
      ShellHelper.progress_bar(items_to_delete, items_to_delete)

      if index.positive? && initial_external_contents_count != external_contents.size
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:clean_up:external_source_data"].reenable
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:clean_up:external_source_data"].invoke(external_source.id)
      end

      # find classifications for extenal_source
      tree_label = DataCycleCore::ClassificationTreeLabel.where(external_source_id: external_source.id)
      puts "Found ClassificationTreeLabels: #{tree_label.count}"
      tree_label.each do |classification_tree_label|
        if classification_tree_label.things.any?
          puts "Found ClassificationTreeLabel with linked content: #{classification_tree_label.id}"
        else
          classification_tree_label.destroy
        end
      end
    end

    desc 'Check all external_sources for orphaned data (does not modify the data)'
    task external_data_check: :environment do
      puts "checking ExternalSystems (#{DataCycleCore::ExternalSystem.count}) dependencies:"
      linked_data = DataCycleCore::ExternalSystem.all.map { |item|
        name = CleanupHelper.identify_external_source(item)
        next if name.blank?
        linked = CleanupHelper.linked(name)
        next if linked.blank?
        { external_source_id: item.id, name: item.name, linked: }
      }.compact

      dirty_data = []

      linked_data.each do |external_source|
        puts "\n#{external_source[:name]}"
        puts '-' * 70
        external_source[:linked].pluck(:template).uniq.each do |dependency|
          all_items = DataCycleCore::Thing.where(
            external_source_id: external_source[:external_source_id],
            template_name: dependency
          ).count
          orphaned_items = DataCycleCore::Thing.left_outer_joins(:content_content_b).where(
            things: {
              external_source_id: external_source[:external_source_id],
              template_name: dependency
            },
            content_contents: {
              content_b_id: nil
            }
          ).pluck(:id)

          recheck = DataCycleCore::ContentContent.where(content_a_id: orphaned_items).or(DataCycleCore::ContentContent.where(content_b_id: orphaned_items)).count
          puts "ERROR: recheck has found  --> #{recheck} <-- orphans still linked to content!!" if recheck.positive?

          dirty_data.push({ name: external_source[:name], id: external_source[:external_source_id], template: dependency }) if orphaned_items.size.positive?
          puts "         #{dependency.ljust(15)}   |   total: #{all_items.to_s.rjust(6)}   |   orphaned: #{orphaned_items.size.to_s.rjust(6)}"
        end
        puts '-' * 70
      end

      if dirty_data.size.positive?
        puts "\nSuggested cleanup Tasks:"
        dirty_data.each do |task|
          puts "#{task[:name].ljust(35)} bundle exec rails #{ENV['CORE_RAKE_PREFIX']}dc:clean_up:external_data#{ShellHelper.zsh? ? '\\' : ''}[#{task[:id]},\"#{task[:template].tr(' ', '\\ ')}\"#{ShellHelper.zsh? ? '\\' : ''}]"
        end
      else
        puts "\n[done] ... looks good"
      end
    end

    desc 'delete orphaned external_data'
    task :external_data, [:external_source_id, :template] => [:environment] do |_, args|
      template = DataCycleCore::Thing.find_by(template_name: args.fetch(:template))
      ShellHelper.error('Error: No template found!') if template.blank?

      external_source = DataCycleCore::ExternalSystem.find_by(id: args.fetch(:external_source_id))
      ShellHelper.error('Error: No ExternalSystem found!') if external_source.blank?

      orphans = DataCycleCore::Thing.left_outer_joins(:content_content_b).where(
        things: {
          external_source_id: external_source.id,
          template_name: template.template_name
        },
        content_contents: {
          content_b_id: nil
        }
      )

      items_to_delete = orphans.count
      puts "Deleting #{items_to_delete.to_s.rjust(6)} #{('(template: ' + template.template_name + ')').ljust(32)} from #{external_source.name.ljust(50)} 0% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\n"

      index = 0
      orphans.each do |orphan|
        ShellHelper.progress_bar(items_to_delete, index)
        index += 1
        orphan.destroy_content(save_history: false, destroy_linked: true)
      end
      ShellHelper.progress_bar(items_to_delete, items_to_delete)
    end

    desc 'Check all embedded for orphaned data (does not modify the data)'
    task embedded_check: :environment do
      puts 'checking embedded_data:'
      puts '-' * 70

      orphaned_data = []
      CleanupHelper.embedded.each do |key, value|
        orphans = CleanupHelper.orphaned_embedded(value.uniq, key)
        total = DataCycleCore::Thing.where(template_name: key).count
        puts "#{key.ljust(25)}  |   total: #{total.to_s.rjust(6)}   |   orphaned: #{orphans.size.to_s.rjust(6)}"
        orphaned_data.push(key) if orphans.size.positive?
      end
      puts '-' * 70

      if orphaned_data.size.positive?
        puts "\nSuggested cleanup Tasks:"
        orphaned_data.each do |embedded|
          puts "#{embedded.to_s.ljust(25)} bundle exec rails #{ENV['CORE_RAKE_PREFIX']}dc:clean_up:embedded#{ShellHelper.zsh? ? '\\' : ''}[\"#{embedded.tr(' ', '\\ ')}\"#{ShellHelper.zsh? ? '\\' : ''}]"
        end
      else
        puts "\n[done] ... looks good"
      end
    end

    desc 'delete orphaned embedded'
    task :embedded, [:embedded] => [:environment] do |_, args|
      embedded_template = args.fetch(:embedded)
      template = DataCycleCore::Thing.find_by(template_name: embedded_template)
      ShellHelper.error("Error: No embedded template found for #{embedded_template}") if template.blank?
      ShellHelper.error("Error: #{embedded_template} is not an embedded template!") unless template.schema.dig('content_type') == 'embedded'

      main_templates = embedded[embedded_template]
      orphans = CleanupHelper.orphaned_embedded(main_templates, embedded_template)
      items_to_delete = orphans.count
      puts "#{('embedded: ' + embedded_template).ljust(25)} used in:  #{main_templates.map(&:to_s)}"
      puts "Deleting #{items_to_delete.to_s.rjust(6)} #{' ' * 88} 0% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\n"

      index = 0
      orphans.each do |orphan|
        ShellHelper.progress_bar(items_to_delete, index)
        index += 1
        orphan.destroy_content(save_history: false)
      end
      ShellHelper.progress_bar(items_to_delete, items_to_delete)
    end

    desc 'find_orphaned_things in mongodb'
    task :find_orphaned_things_in_mongodb, [:template_name, :external_system_id, :collection_name] => [:environment] do |_, args|
      collection_name = args.fetch(:collection_name, false)
      external_system_id = args.fetch(:external_system_id, false)
      template_name = args.fetch(:template_name, false)

      ShellHelper.error 'invalid number of arguments' unless collection_name.present? && external_system_id.present? && template_name.present?

      external_system = DataCycleCore::ExternalSystem.find(external_system_id)
      things = DataCycleCore::Thing.where(template_name:, external_source_id: external_system.id)

      puts "things (#{template_name}) found: #{things.size}\n"

      things_missing = 0
      things_missing_keys = []

      external_system.collection(collection_name) do |collection|
        things.each do |thing|
          next unless collection.find({ 'external_id': thing.external_key }).count.zero?
          # puts "item with external key: #{thing.external_key} not found in mongo collection\n"
          things_missing += 1
          things_missing_keys << thing
          next
        end
      end
      puts "things (#{template_name}) missing in mongoDB: #{things_missing}\n"
    end
  end
end
