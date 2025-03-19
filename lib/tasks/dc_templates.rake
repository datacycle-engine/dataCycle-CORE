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

        # Count the amount of datasets, where not country_code is used but country for nationality
        rows_to_update = ActiveRecord::Base.connection.execute <<-SQL.squish
            SELECT 1 from things as th
              JOIN classification_contents as cc ON th.id = cc.content_data_id
              JOIN classifications as cl ON cc.classification_id = cl.id
              JOIN concepts AS co ON cl.id = co.classification_id
              JOIN concept_schemes AS cs ON cs.id = co.concept_scheme_id#{' '}
                AND cs.name = '#{from_concept_scheme_name}'
              JOIN concept_schemes AS cs2 ON cs2.name = '#{to_concept_scheme_name}'
              JOIN concepts AS co2 ON cs2.id = co2.concept_scheme_id
              JOIN classifications as cl2 ON cl2.id = co2.classification_id#{' '}
                AND cl2.description = cl.name
              WHERE
                cc.relation = '#{relation}'
              AND th.template_name = '#{template_name}'
        SQL
        puts "Datasets to migrate:  #{rows_to_update.count}\n"

        # Update the classification id in classification_contents from the old country to the new country_codes id
        rows_affected = ActiveRecord::Base.connection.execute <<-SQL.squish
            UPDATE classification_contents as c1
                SET classification_id = (
                SELECT cl2.id from classifications as cl
                  JOIN concepts AS co ON cl.id = co.classification_id
                  JOIN concept_schemes AS cs ON cs.id = co.concept_scheme_id
                    AND cs.name = '#{from_concept_scheme_name}'
                  JOIN concept_schemes AS cs2 ON cs2.name = '#{to_concept_scheme_name}'
                  JOIN concepts AS co2 ON cs2.id = co2.concept_scheme_id
                  JOIN classifications as cl2 ON cl2.id = co2.classification_id
                    AND cl2.description = cl.name
                  WHERE c1.classification_id = cl.id
                )
                WHERE
                EXISTS (
                  SELECT 1 from things AS th
                    JOIN concepts AS co ON c1.classification_id = co.classification_id
                    JOIN classifications AS cl1 ON cl1.id = c1.classification_id
                    JOIN classifications as cl2 ON cl2.description = cl1.name
                    JOIN concepts AS co2 ON co2.classification_id = cl2.id
                    JOIN concept_schemes AS cs ON co.concept_scheme_id = cs.id AND cs.name = '#{from_concept_scheme_name}'
                    JOIN concept_schemes AS cs2 ON cs2.id = co2.concept_scheme_id AND cs2.name = '#{to_concept_scheme_name}'
                    WHERE c1.content_data_id = th.id
                      AND th.template_name = '#{template_name}'
                      AND c1.relation = '#{relation}'
                )
                RETURNING c1.content_data_id
        SQL
        puts "Datasets migrated:  #{rows_affected.cmd_tuples}\n"

        # valid things -> update things column
        content_data_ids = rows_affected.map { |row| "'#{row['content_data_id']}'" }.join(',')
        if content_data_ids.present?
          rows_affected = ActiveRecord::Base.connection.execute <<-SQL.squish
          UPDATE things AS th
          SET cache_valid_since = null
          WHERE
            th.id IN (#{content_data_ids})
          SQL
          puts "Cache Valid Timestamp removed for #{rows_affected.cmd_tuples} rows.\n"

        end
      end
    end
  end
end
