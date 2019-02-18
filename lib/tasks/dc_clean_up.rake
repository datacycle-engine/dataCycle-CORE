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
        # progress_bar
        if items_to_delete > 49
          if (index % 500).zero?
            fraction = (index / (items_to_delete / 100.0)).round(0)
            fraction = 100 if fraction > 100
            print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
          end
        else
          fraction = (((index * 1.0) / items_to_delete) * 100.0).round(0)
          fraction = 100 if fraction > 100
          print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
        end
        index += 1

        data_item.destroy_content
      end
      puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"

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
  end
end
