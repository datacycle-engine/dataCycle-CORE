# frozen_string_literal: true

namespace :dc do
  namespace :clean_up do
    desc 'Remove all data from external_source'
    task :external_source_data, [:external_source_id, :dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false)
      external_source = DataCycleCore::ExternalSource.find(args.fetch(:external_source_id))

      if external_source.nil?
        puts 'Error: No ExternalSource found!'
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
        progress_bar(items_to_delete, index)
        index += 1

        data_item.destroy_content
      end
      progress_bar(items_to_delete, items_to_delete)

      if index.positive? && initial_external_contents_count != external_contents.size
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:clean_up:external_source_data"].reenable
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:clean_up:external_source_data"].invoke(external_source.id)
      end

      # find classifications for extenal_source
      tree_label = DataCycleCore::ClassificationTreeLabel.where(external_source_id: external_source.id)
      puts "Found ClassificationTreeLabels: #{tree_label.count}"
      tree_label.each do |classification_tree_label|
        if classification_tree_label.statistics.linked_content_count.positive?
          puts "Found ClassificationTreeLabel with linked content: #{classification_tree_label.id}"
        else
          classification_tree_label.destroy
        end
      end
    end

    desc 'Check all external_sources for orphaned data (does not modify the data)'
    task external_data_check: :environment do
      puts "checking ExternalSources (#{DataCycleCore::ExternalSource.count}) dependencies:"
      linked_data = DataCycleCore::ExternalSource.all.map { |item|
        name = identify_external_source(item)
        next if name.blank?
        linked = linked(name)
        next if linked.blank?
        { external_source_id: item.id, name: item.name, linked: linked }
      }.compact

      dirty_data = []

      linked_data.each do |external_source|
        puts "\n#{external_source[:name]}"
        puts '-' * 70
        external_source[:linked].map { |link_dep| link_dep[:template] }.uniq.each do |dependency|
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
          puts "#{task[:name].ljust(35)} bundle exec rails #{ENV['CORE_RAKE_PREFIX']}dc:clean_up:external_data#{zsh? ? '\\' : ''}[#{task[:id]},\"#{task[:template].tr(' ', '\\ ')}\"#{zsh? ? '\\' : ''}]"
        end
      else
        puts "\n[done] ... looks good"
      end
    end

    desc 'delete orphaned external_data'
    task :external_data, [:external_source_id, :template] => [:environment] do |_, args|
      template = DataCycleCore::Thing.find_by(template: false, template_name: args.fetch(:template))
      error('Error: No template found!') if template.blank?

      external_source = DataCycleCore::ExternalSource.find_by(id: args.fetch(:external_source_id))
      error('Error: No ExternalSource found!') if external_source.blank?

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
        progress_bar(items_to_delete, index)
        index += 1
        orphan.destroy_content(save_history: false, destroy_linked: true)
      end
      progress_bar(items_to_delete, items_to_delete)
    end

    def identify_external_source(item)
      return nil if item.config.blank?
      item.config.dig('download_config').first[1].dig('endpoint').split('::')[-2]
    end

    def linked(external_source)
      core_data_templates = {
        'Booking' => ['Unterkunft'],
        'EventDatabase' => ['Event'],
        'Feratel' => ['Event', 'POI', 'Unterkunft'],
        'MediaArchive' => ['Bild', 'Video'],
        'OutdoorActive' => ['POI', 'Tour'],
        'VTicket' => ['Event'],
        'Xamoom' => ['Örtlichkeit']
      }.dig(external_source)
      return if core_data_templates.blank?
      core_data_templates&.map do |template|
        thing_template = DataCycleCore::Thing.find_by(template_name: template, template: true)
        thing_template.linked_property_names.map do |linked_item|
          properties = thing_template.properties_for(linked_item)
          if properties.dig('template_name').present?
            { relation: linked_item, template: properties.dig('template_name') }
          elsif properties.dig('stored_filter').present?
            properties.dig('stored_filter').first.dig('with_classification_aliases_and_treename', 'aliases').map do |item|
              { relation: linked_item, template: item }
            end
          end
        end
      end&.flatten&.uniq
    end

    desc 'Check all embedded for orphaned data (does not modify the data)'
    task embedded_check: :environment do
      puts 'checking embedded_data:'
      puts '-' * 70

      orphaned_data = []
      embedded.each do |key, value|
        orphans = orphaned_embedded(value.uniq, key)
        total = DataCycleCore::Thing.where(template: false, template_name: key).count
        puts "#{key.ljust(25)}  |   total: #{total.to_s.rjust(6)}   |   orphaned: #{orphans.size.to_s.rjust(6)}"
        orphaned_data.push(key) if orphans.size.positive?
      end
      puts '-' * 70

      if orphaned_data.size.positive?
        puts "\nSuggested cleanup Tasks:"
        orphaned_data.each do |embedded|
          puts "#{embedded.to_s.ljust(25)} bundle exec rails #{ENV['CORE_RAKE_PREFIX']}dc:clean_up:embedded#{zsh? ? '\\' : ''}[\"#{embedded.tr(' ', '\\ ')}\"#{zsh? ? '\\' : ''}]"
        end
      else
        puts "\n[done] ... looks good"
      end
    end

    desc 'delete orphaned embedded'
    task :embedded, [:embedded] => [:environment] do |_, args|
      embedded_template = args.fetch(:embedded)
      template = DataCycleCore::Thing.find_by(template_name: embedded_template)
      error("Error: No embedded template found for #{embedded_template}") if template.blank?
      error("Error: #{embedded_template} is not an embedded template!") unless template.schema.dig('content_type') == 'embedded'

      main_templates = embedded[embedded_template]
      orphans = orphaned_embedded(main_templates, embedded_template)
      items_to_delete = orphans.count
      puts "#{('embedded: ' + embedded_template).ljust(25)} used in:  #{main_templates.map(&:to_s)}"
      puts "Deleting #{items_to_delete.to_s.rjust(6)} #{' ' * 88} 0% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\n"

      index = 0
      orphans.each do |orphan|
        progress_bar(items_to_delete, index)
        index += 1
        orphan.destroy_content(save_history: false)
      end
      progress_bar(items_to_delete, items_to_delete)
    end

    def embedded
      embedded_hash = {}
      DataCycleCore::Thing.where(template: true).find_each.select { |temp| temp.content_type == 'entity' }.map do |main_temp|
        main_temp.embedded_property_names.map do |embedded_item|
          properties = main_temp.properties_for(embedded_item)
          if embedded_hash.key?(properties.dig('template_name'))
            embedded_hash[properties.dig('template_name')].push(main_temp.template_name)
          else
            embedded_hash[properties.dig('template_name')] = [main_temp.template_name]
          end
        end
      end
      embedded_hash.map { |key, value| { key => value.uniq } }.reduce({}, &:merge)
    end

    def orphaned_embedded(template_array, embedded_name)
      template_string = "'" + template_array.map(&:to_s).join("', '") + "'"
      where_string = <<-EOS
      things.id NOT IN (
        SELECT things.id FROM things
        INNER JOIN content_contents ON content_contents.content_b_id = things.id
        INNER JOIN things things2 ON content_contents.content_a_id = things2.id
        WHERE things.template = false
        AND things.template_name = '#{embedded_name}'
        AND things2.template = false
        AND things2.template_name IN (#{template_string})
      )
      EOS

      DataCycleCore::Thing.where(template: false, template_name: embedded_name).where(where_string)
    end
  end
end

def progress_bar(total_items, index, interval = nil)
  if index >= total_items
    print "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\n"
    return
  end
  interval ||= [total_items / 100.0, 1.0].max.round(0)
  return unless (index % interval).zero?
  fraction = (((index * 1.0) / total_items) * 100.0).round(0)
  fraction = 100 if fraction > 100
  print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
end

def zsh?
  ENV['SHELL'].split('/').last == 'zsh'
end

def error(msg)
  puts msg
  exit(-1)
end
