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
        mappings = DataCycleCore.data_definition_mapping['templates']

        template_names = DataCycleCore::ThingTemplate.pluck(:template_name)

        no_matched_keys = []
        mappings.each do |key, value|
          no_matched_keys << key if template_names.include?(key) && template_names.exclude?(value)
        end

        puts "No matched keys: #{no_matched_keys}"
      end

      task :data_definitions, [:debug] => :environment do |_, _args|
        puts "migrate to new data_definitions\n"
        mappings = DataCycleCore.data_definition_mapping['templates']

        mappings.each do |key, value|
          if key == value
            puts "Key equals value - skip mapping #{key}: #{value}"
            next
          end

          thing_templates = DataCycleCore::ThingTemplate.where(template_name: [key, value])
          if thing_templates.count != 2
            puts "Key (#{key}) or value (#{value}) not known in thing_templates - skip mapping #{key}: #{value}"
            next
          end

          things = DataCycleCore::Thing.where(template_name: key)
          puts "Changing things template_name #{key} to #{value} for: #{things.count} rows"
          things.each do |thing|
            thing.update(template_name: value, cache_valid_since: nil)
          end

          old_things_count = DataCycleCore::Thing.where(template_name: value).count
          new_things_count = DataCycleCore::Thing.where(template_name: key).count
          puts "things with template_name new template_name #{value}: #{old_things_count} rows"
          puts "things with template_name old template_name #{key}: #{new_things_count} rows"
        end
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
        from_concept_scheme_name = args.from
        to_concept_scheme_name = args.to
        template_name = args.template
        relation = args.relation

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

      # value => translated_value (copy vs move)
      desc 'value => translated (copy/move) | templates as one space seperated string'
      task :value_to_translated, [:from, :to, :operation, :templates, :debug] => :environment do |_, args|
        field_from = args.from
        field_to = args.to
        templates = args.templates&.split
        puts "migrate #{field_from} to translated #{field_to} for templates #{templates} | Operation: #{args[:operation]}\n"

        # count how many rows should be affected by the migration
        select_th_qry = <<-SQL.squish
          SELECT 1
          FROM things AS t1
            JOIN thing_translations ON t1.id = thing_translations.thing_id
          WHERE t1.metadata->? IS NOT NULL
            #{' AND t1.template_name IN (?)' if templates.present?}
        SQL
        query_args = [field_from]
        query_args << templates if templates.present?
        sanitized_select_th_qry = ActiveRecord::Base.sanitize_sql_array([select_th_qry, *query_args])
        rows_to_update = ActiveRecord::Base.connection.select_all(sanitized_select_th_qry)
        puts "Datasets to migrate:  #{rows_to_update.count}\n"

        # migrate data
        update_tt_qry = <<-SQL.squish
          UPDATE thing_translations AS tt
          SET content = jsonb_set(tt.content, ?, data_origin.metadata->?)
          FROM (
                  SELECT th.metadata, th.id
                  FROM things AS th
                  WHERE th.metadata->? IS NOT NULL
                      #{' AND th.template_name IN (?)' if templates.present?}
              ) AS data_origin
          WHERE tt.thing_id = data_origin.id
        SQL

        query_args = ["{#{field_to}}", field_from, field_from]
        query_args << templates if templates.present?
        sanitized_update_tt_qry = ActiveRecord::Base.sanitize_sql_array([update_tt_qry, *query_args])
        rows_updated = ActiveRecord::Base.connection.exec_update(sanitized_update_tt_qry)
        puts "Datasets migrated:  #{rows_updated}\n"

        # remove old fields from metadata json, if operation equals move
        if args[:operation] == 'move'
          remove_metadata_fields_qry = <<-SQL.squish
            UPDATE things
            SET metadata = metadata - ?
            WHERE things.metadata->? IS NOT NULL
              #{' AND things.template_name IN (?)' if templates.present?}
          SQL

          query_args = [field_from, field_from]
          query_args << templates if templates.present?
          sanitized_remove_metadata_fields_qry = ActiveRecord::Base.sanitize_sql_array([remove_metadata_fields_qry, *query_args])
          deleted = ActiveRecord::Base.connection.exec_update(sanitized_remove_metadata_fields_qry)
          puts "Original values deleted: #{deleted}\n"
        end
      end

      # translated => simple_value (copy/move)
      desc 'translated => value (copy/move)'
      task :translated_to_value, [:from, :to, :operation, :templates, :debug] => :environment do |_, args|
        field_from = args.from
        field_to = args.to
        templates = args.templates&.split
        puts "migrate translated #{field_from} to #{field_to} for templates #{templates} | Operation: #{args[:operation]}\n"

        # count how many rows should be affected by the migration
        select_tt_qry = <<-SQL.squish
          SELECT 1
          FROM thing_translations AS t1
            JOIN things AS t2 ON t1.thing_id = t2.id
          WHERE t1.content->? IS NOT NULL
            AND t1.locale = 'de' #{'AND t2.template_name IN (?)' if templates.present?}
        SQL

        query_args = [field_from]
        query_args << templates if templates.present?
        sanitized_select_tt_qry = ActiveRecord::Base.sanitize_sql_array([select_tt_qry, *query_args])
        rows_to_update = ActiveRecord::Base.connection.select_all(sanitized_select_tt_qry)
        puts "Datasets to migrate:  #{rows_to_update.count}\n"

        # migrate data
        update_th_qry = <<-SQL.squish
          UPDATE things AS th
          SET metadata = jsonb_set(th.metadata, ?, data_origin.content->?)
          FROM (
                  SELECT tt.content, tt.thing_id
                  FROM thing_translations as tt
                  WHERE tt.content->? IS NOT NULL
                      AND tt.locale = 'de'
              ) AS data_origin
          WHERE th.id = data_origin.thing_id
            #{' AND th.template_name IN (?)' if templates.present?}
        SQL

        query_args = ["{#{field_to}}", field_from, field_from]
        query_args << templates if templates.present?
        sanitized_update_th_qry = ActiveRecord::Base.sanitize_sql_array([update_th_qry, *query_args])
        rows_updated = ActiveRecord::Base.connection.exec_update(sanitized_update_th_qry)
        puts "Datasets migrated:  #{rows_updated}\n"

        # remove old fields from metadata json, if operation equals move
        if args[:operation] == 'move'
          remove_metadata_fields_qry = <<-SQL.squish
            UPDATE thing_translations t1
            SET content = content - ?
            WHERE EXISTS (
                SELECT 1 FROM things as t2
                WHERE t1.thing_id = t2.id
                  AND t2.metadata->? IS NOT NULL
                  #{'AND t2.template_name IN (?)' if templates.present?}
              )
              AND t1.content->? IS NOT NULL
          SQL

          query_args = [field_from, field_to]
          query_args << templates if templates.present?
          query_args << field_from
          sanitized_remove_metadata_fields_qry = ActiveRecord::Base.sanitize_sql_array([remove_metadata_fields_qry, *query_args])
          deleted = ActiveRecord::Base.connection.exec_update(sanitized_remove_metadata_fields_qry)
          puts "Original values deleted: #{deleted}\n"
        end
      end
    end
  end
end
