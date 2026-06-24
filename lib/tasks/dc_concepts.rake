# frozen_string_literal: true

namespace :dc do
  namespace :concepts do
    desc 'import new concepts from classifications.yml'
    task :import, [:verbose] => :environment do |_, _args|
      before_import = Time.zone.now
      puts 'importing new concepts'
      importer = DataCycleCore::MasterData::Concepts::ConceptImporter.new
      importer.import
      importer.render_errors

      importer.valid? ? puts(AmazingPrint::Colors.green("[✔] ... looks good 🚀 (Duration: #{(Time.zone.now - before_import).round} sec, #{format('%+d', importer.counts[:concept_schemes])}/#{format('%+d', importer.counts[:concepts])}/#{format('%+d', importer.counts[:concept_mappings])})")) : exit(-1)
    end

    desc 'import new concept mappings from path'
    task :import_mappings, [:path] => :environment do |_, args|
      before_import = Time.zone.now
      path = args.path
      abort('Please provide a path to folder with classification_mappings.yml inside') if path.blank?

      full_path = Rails.root.join(path)

      puts "importing new concept_mappings from #{full_path}"
      importer = DataCycleCore::MasterData::Concepts::ConceptImporter.new(paths: full_path, import_concepts: false)
      importer.import
      importer.render_errors

      importer.valid? ? puts(AmazingPrint::Colors.green("[✔] ... looks good 🚀 (Duration: #{(Time.zone.now - before_import).round} sec, #{format('%+d', importer.counts[:concept_mappings])})")) : exit(-1)
    end

    desc 'merge duplicate system classifications'
    task merge_system_duplicates: :environment do
      duplicates = ActiveRecord::Base.connection.exec_query <<~SQL.squish
        WITH duplicates AS (
          SELECT id,
            concept_scheme_id,
            external_key,
            external_system_id,
            COUNT(*) over (PARTITION by concept_scheme_id, external_key) AS duplicate_count
          FROM public.concepts
          WHERE external_system_id IS NULL
            AND external_key IS NOT NULL
          ORDER BY concept_scheme_id,
            external_key,
            created_at ASC
        )
        SELECT array_agg(duplicates.id) AS concept_ids
        FROM duplicates
        WHERE duplicates.duplicate_count > 1
        GROUP BY duplicates.concept_scheme_id,
          duplicates.external_key;
      SQL

      concept_ids = duplicates.cast_values
      aliases = DataCycleCore::ClassificationAlias.where(id: concept_ids.flatten).index_by(&:id)

      concept_ids.each do |ids|
        original = aliases[ids.shift]

        print "\n#{original.external_key} "

        ids.each do |id|
          duplicate = aliases[id]
          duplicate.merge_with_children(original)
          print '.'
        end

        print AmazingPrint::Colors.green('✔')
      end

      puts AmazingPrint::Colors.green("\n[done] finished merge")
    end
  end
end
