# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :refactor do
    desc 'Merge duplicates of classifications'
    task :merge_duplicate_classifications, [:classification_tree_name] => :environment do |_, args|
      duplicates = DataCycleCore::ClassificationAlias
        .joins('join classification_alias_paths on classification_alias_paths.id = classification_aliases.id AND classification_aliases.deleted_at is null')
        .includes(:classification_tree_label, :primary_classification, :classification_tree)
        .select('array_agg(classifications.id), classification_alias_paths.full_path_names, classification_alias_paths.ancestor_ids')
        .where("classification_tree_labels.name = '#{args.classification_tree_name}' AND NOT EXISTS (SELECT FROM classification_alias_paths cap2 WHERE classification_alias_paths.id = cap2.ancestor_ids[1])")
        .group('classification_alias_paths.full_path_names', 'classification_alias_paths.ancestor_ids')
        .having('COUNT(*) > 1')
        .pluck('array_agg(classifications.id), classification_alias_paths.full_path_names, classification_alias_paths.ancestor_ids')

      puts "Merging #{duplicates.size} duplicated classifications of Classification Tree: #{args.classification_tree_name} ... "

      duplicates.each do |d|
        duplicate_ids = d[0]
        original_id = duplicate_ids[0]
        original_content_ids = DataCycleCore::ClassificationContent.where(classification_id: original_id).map(&:content_data_id)

        puts "Merging #{duplicate_ids.size} duplicates of  #{d[1].reverse} ... "

        duplicate_ids.drop(1).compact.each do |duplicate_id|
          original_id_alias = DataCycleCore::Classification.find(original_id).primary_classification_alias
          duplicate_id_alias = DataCycleCore::Classification.find(duplicate_id).primary_classification_alias

          puts "Replacing duplicate #{duplicate_id} with original #{original_id}"

          DataCycleCore::ClassificationContent.where(classification_id: duplicate_id)&.find_each do |cc|
            if original_content_ids.include? cc.content_data_id
              cc.destroy
            else
              cc.update_columns(classification_id: original_id) # rubocop:disable Rails/SkipsModelValidations
              # prevent error due to multiple tagging
              original_content_ids.push(cc.content_data_id)
            end
          end

          DataCycleCore::ClassificationContent::History.where(classification_id: duplicate_id).update_all(classification_id: original_id)

          DataCycleCore::StoredFilter.update_all("parameters = replace(parameters::text, '#{duplicate_id_alias.id}', '#{original_id_alias.id}')::jsonb")

          DataCycleCore::Search.update_all("classification_aliases_mapping = array_replace(classification_aliases_mapping, '#{duplicate_id_alias.id}', '#{original_id_alias.id}')")

          DataCycleCore::ClassificationAlias.find(duplicate_id_alias.id).destroy
        end

        puts "Merging #{duplicate_ids.size} duplicates of  #{d[1].reverse} ... [DONE]"
      end

      puts "Merging #{duplicates.size} duplicated classifications of Classification Tree: #{args.classification_tree_name} ... [DONE]"
    end

    desc 'import and update all templates'
<<<<<<< HEAD
    task :import_update_all_templates, [:templates] => :environment do |_, args|
      template_names = args.fetch(:templates, nil)&.split('|')&.map(&:squish)
=======
    task import_update_all_templates: :environment do
>>>>>>> old/develop
      temp = Time.zone.now

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_templates"].invoke

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:check:invalid_overlay_definitions"].invoke

<<<<<<< HEAD
      if template_names.present?
        template_names.each do |template_name|
          Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:update_template_sql"].invoke(template_name, false)
          Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:update_template_sql"].reenable
        end
      else
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:update_all_templates_sql"].invoke(false)
      end

      puts 'END'
      puts "--> MIGRATION time: #{(Time.zone.now - temp)} sec"
=======
      puts 'END'
      puts "--> MIGRATION time: #{Time.zone.now - temp} sec"
>>>>>>> old/develop
    end
  end
end
