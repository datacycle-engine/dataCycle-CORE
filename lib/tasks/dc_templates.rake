# frozen_string_literal: true

namespace :dc do
  namespace :templates do
    desc 'validate template definitions'
    task :validate, [:verbose] => :environment do |_, args|
      puts "validating new template definitions\n"
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new
      template_importer.validate

      template_importer.render_mixin_errors
      template_importer.render_errors
      template_importer.render_mixin_paths if args.verbose.to_s.casecmp('true').zero?

      template_importer.valid? ? puts(AmazingPrint::Colors.green('[✔] ... looks good 🚀')) : exit(-1)
    end

    desc 'import and update all template definitions'
    task :import, [:verbose] => :environment do |_, args|
      before_import = Time.zone.now
      puts "importing new template definitions\n"
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new
      template_importer.import

      template_importer.render_duplicates if args.verbose.to_s.casecmp('true').zero?
      template_importer.render_mixin_errors
      template_importer.render_errors
      template_importer.render_mixin_paths if args.verbose.to_s.casecmp('true').zero?

      template_importer.valid? ? puts(AmazingPrint::Colors.green("[✓] ... looks good 🚀 (Duration: #{(Time.zone.now - before_import).round} sec)")) : exit(-1)

      template_statistics = DataCycleCore::MasterData::Templates::TemplateStatistics.new(start_time: before_import)
      template_statistics.update_statistics
      template_statistics.render_statistics
    end

    namespace :migrations do
      task :validate, [:debug] => :environment do |_, _args|
        puts "validating new data definitions\n"
      end
      task :data_definitions, [:debug] => :environment do |_, _args|
        puts "migrate to new data_definitions\n"
      end
      task :universal_classifications, [:debug] => :environment do |_, _args|
        puts "migrate classifications to universal classifications\n"
        if DataCycleCore.data_definition_mapping['universal_classifications'].blank?
          puts 'no mappings found'
          exit(-1)
        end
        classifications = DataCycleCore.data_definition_mapping['universal_classifications']
        ap classifications
        ActiveRecord::Base.connection.execute <<-SQL.squish
          UPDATE classification_contents SET relation = 'universal_classifications' WHERE relation IN ('#{classifications.join("','")}');
          UPDATE classification_content_histories SET relation = 'universal_classifications' WHERE relation IN ('#{classifications.join("','")}');
        SQL
      end
      task :embedded_relations, [:debug] => :environment do |_, _args|
        puts "migrate content_contents to new relations\n"
        if DataCycleCore.data_definition_mapping['embedded_relations'].blank?
          puts 'no mappings found'
          exit(-1)
        end
        content_contents_mapping = DataCycleCore.data_definition_mapping['embedded_relations']
        ap content_contents_mapping

        content_contents_mapping.each do |old, new|
          ActiveRecord::Base.connection.execute <<-SQL.squish
            UPDATE content_contents SET relation_a = '#{new}' WHERE relation_a = '#{old}';
            UPDATE content_content_histories SET relation_a = '#{new}' WHERE relation_a = '#{old}';
          SQL
          puts "migrated #{old} to #{new}"
        end
      end
      task :media_obects_translated_url, [:debug] => :environment do |_, _args|
        puts "migrate media objects ('ImageObject', 'VideoObject', 'AudioObject', 'ImageObjectVariant', 'ExternalVideo') to use translated urls\n"

        ActiveRecord::Base.connection.execute <<-SQL.squish
          UPDATE thing_translations AS t1
          SET content = jsonb_set(
            t1.content,
            '{url}',
            (SELECT things.metadata->'url' from things where things.id = t1.thing_id)
          )
          WHERE EXISTS (
              SELECT 1
              FROM things
              WHERE things.id = t1.thing_id AND things.template_name IN ('ImageObject', 'VideoObject', 'AudioObject', 'ImageObjectVariant', 'ExternalVideo') AND things.metadata->'url' IS NOT NULL
          );

          UPDATE things
          SET metadata = metadata - 'url'
          WHERE things.template_name IN ('ImageObject', 'VideoObject', 'AudioObject', 'ImageObjectVariant', 'ExternalVideo')
        SQL
      end

      # switches classification_id in classification_contents according to their classification_tree_labels
      desc 'changes classification_id for things according to old and new tree_label'
      task :update_classification_contents_based_on_similarity, [:from, :to, :template, :relation, :debug] => :environment do |_, args|
        puts "Starting to migrate countries to their corresponding country codes\n"
        from_concept_scheme_name = args[:from]
        to_concept_scheme_name = args[:to]
        template_name = args[:template]
        relation = args[:relation]

        # Count the amount of datasets that need to be updated
        select_cc = <<-SQL.squish
          SELECT co2.classification_id AS new_classification_id, cc.id
          FROM classification_contents AS cc
            JOIN concepts AS co ON cc.classification_id = co.classification_id
            JOIN concept_schemes AS cs ON cs.id = co.concept_scheme_id
              AND cs.name = ?
            JOIN concepts AS co2 ON co2.description_i18n->>'de' = co.internal_name
            JOIN concept_schemes AS cs2 ON cs2.id = co2.concept_scheme_id
              AND cs2.name = ?
            JOIN things AS th ON th.id = cc.content_data_id
              AND th.template_name = ?
          WHERE cc.relation = ?
        SQL
        sanitized_select_cc = ActiveRecord::Base.send(:sanitize_sql_array, [select_cc, from_concept_scheme_name, to_concept_scheme_name, template_name, relation])
        rows_to_update = ActiveRecord::Base.connection.select_all(sanitized_select_cc)
        puts "Datasets to migrate:  #{rows_to_update.count}\n"

        # Update the classification id in classification_contents old to new classification_ids
        update_cc = <<-SQL.squish
          WITH classification_contents_update AS (
            UPDATE classification_contents as c1
            SET classification_id = cl_update.new_classification_id
            FROM (
                SELECT co2.classification_id AS new_classification_id,
                  cc.id
                FROM classification_contents AS cc
                  JOIN concepts AS co ON cc.classification_id = co.classification_id
                  JOIN concept_schemes AS cs ON cs.id = co.concept_scheme_id
                    AND cs.name = ?
                  JOIN concepts AS co2 ON co2.description_i18n->>'de' = co.internal_name
                  JOIN concept_schemes AS cs2 ON cs2.id = co2.concept_scheme_id
                    AND cs2.name = ?
                  JOIN things AS th ON th.id = cc.content_data_id
                    AND th.template_name = ?
                WHERE cc.relation = ?
              ) as cl_update
            WHERE c1.id = cl_update.id
            RETURNING c1.content_data_id
          )
          UPDATE things AS th
          SET cache_valid_since = null
          WHERE th.id IN (
              SELECT content_data_id
              FROM classification_contents_update
            )
        SQL

        sanitized_update_cc = ActiveRecord::Base.send(:sanitize_sql_array, [update_cc, from_concept_scheme_name, to_concept_scheme_name, template_name, relation])
        rows_updated = ActiveRecord::Base.connection.exec_update(sanitized_update_cc)
        puts "Datasets migrated:  #{rows_updated}\n"
      end
    end
  end
end
