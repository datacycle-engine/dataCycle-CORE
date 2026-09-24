# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :refactor do
    desc 'Merge duplicates of classifications'
    task :merge_duplicate_classifications, [:concept_scheme_name] => :environment do |_, args|
      duplicates = DataCycleCore::Concept
        .joins(:concept_path, :concept_scheme)
        .where(concept_schemes: { name: args.concept_scheme_name })
        .where('NOT EXISTS (SELECT FROM concept_paths cap2 WHERE concept_paths.id = cap2.ancestor_ids[1])')
        .group('concept_paths.full_path_names', 'concept_paths.ancestor_ids')
        .having('COUNT(*) > 1')
        # Concept's default_scope orders by order_a, which PG rejects next to this GROUP BY.
        .reorder(nil)
        .pluck(Arel.sql('array_agg(concepts.id), concept_paths.full_path_names'))

      puts "Merging #{duplicates.size} duplicated concepts of concept scheme: #{args.concept_scheme_name} ... "

      duplicates.each do |ids, full_path_names|
        original_id, *duplicate_ids = ids.compact

        puts "Merging #{duplicate_ids.size} duplicates of #{full_path_names.reverse} ... "

        # merge_with moves the contents, the mappings, the polygons and the stored filter parameters
        # over and destroys the source - what this task used to do by hand, and got wrong.
        original = DataCycleCore::Concept.find(original_id)
        duplicate_ids.each { |duplicate_id| DataCycleCore::Concept.find(duplicate_id).merge_with(original) }

        puts "Merging #{duplicate_ids.size} duplicates of #{full_path_names.reverse} ... [DONE]"
      end

      puts "Merging #{duplicates.size} duplicated concepts of concept scheme: #{args.concept_scheme_name} ... [DONE]"
    end

    desc 'import and update all templates'
    task import_update_all_templates: :environment do
      temp = Time.zone.now

      Rake::Task['dc:templates:import'].invoke
      Rake::Task['dc:templates:import'].reenable

      puts 'END'
      puts "--> MIGRATION time: #{Time.zone.now - temp} sec"
    end
  end
end
