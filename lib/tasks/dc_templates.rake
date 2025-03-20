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

      # value => translated_value (copy vs move)
      desc 'value => translated (copy/move) | templates as one space seperated string'
      task :value_to_translated, [:from, :to, :operation, :templates, :debug] => :environment do |_, args|
        field_from = args[:from]
        field_to = args[:to]
        templates = args[:templates].split
        puts "migrate #{field_from} to translated #{field_to} for templates #{templates} | Operation: #{args[:operation]}\n"

        # count how many rows should be affected by the migration
        select_th_qry = <<-SQL.squish
          SELECT 1
          FROM things AS t1
            JOIN thing_translations ON t1.id = thing_translations.thing_id
          WHERE t1.metadata->? IS NOT NULL#{' '}
            #{'AND t1.template_name IN (?)' if templates.present?}
        SQL
        sanitized_select_th_qry = ActiveRecord::Base.sanitize_sql_array([select_th_qry, field_from, templates])
        rows_to_update = ActiveRecord::Base.connection.select_all(sanitized_select_th_qry)
        puts "Datasets to migrate:  #{rows_to_update.count}\n"

        # migrate data
        update_tt_qry = <<-SQL.squish
          UPDATE thing_translations AS t1
          SET content = jsonb_set(
              t1.content,
              ?,
              (
                SELECT things.metadata->?
                from things
                where things.id = t1.thing_id
              )
            )
          WHERE EXISTS (
              SELECT 1
              FROM things
              WHERE things.id = t1.thing_id
                AND things.metadata->? IS NOT NULL#{' '}
                  #{'AND things.template_name IN (?)' if templates.present?}
            )
        SQL
        sanitized_update_tt_qry = ActiveRecord::Base.sanitize_sql_array([update_tt_qry, "{#{field_to}}", field_from, field_from, templates])
        rows_updated = ActiveRecord::Base.connection.exec_update(sanitized_update_tt_qry)
        puts "Datasets migrated:  #{rows_updated}\n"

        # remove old fields from metadata json, if operation equals move
        if args[:operation] == 'move'
          remove_metadata_fields_qry = <<-SQL.squish
            UPDATE things
            SET metadata = metadata - ?
            WHERE things.metadata->? IS NOT NULL#{' '}
              #{'AND things.template_name IN (?)' if templates.present?}
          SQL
          sanitized_remove_metadata_fields_qry = ActiveRecord::Base.sanitize_sql_array([remove_metadata_fields_qry, field_from, field_from, templates])
          deleted = ActiveRecord::Base.connection.exec_update(sanitized_remove_metadata_fields_qry)
          puts "Original values deleted: #{deleted}\n"
        end
      end

      # translated => simple_value (copy/move)
      desc 'translated => value (copy/move)'
      task :translated_to_value, [:from, :to, :operation, :templates, :debug] => :environment do |_, args|
        field_from = args[:from]
        field_to = args[:to]
        templates = args[:templates].split
        puts "migrate translated #{field_from} to #{field_to} for templates #{templates} | Operation: #{args[:operation]}\n"

        # count how many rows should be affected by the migration
        select_tt_qry = <<-SQL.squish
          SELECT 1
          FROM thing_translations AS t1
            JOIN things AS t2 ON t1.thing_id = t2.id
          WHERE t1.content->? IS NOT NULL
            AND t1.locale = 'de' #{'AND t2.template_name IN (?)' if templates.present?}
        SQL
        sanitized_select_tt_qry = ActiveRecord::Base.sanitize_sql_array([select_tt_qry, field_from, templates])
        rows_to_update = ActiveRecord::Base.connection.select_all(sanitized_select_tt_qry)
        puts "Datasets to migrate:  #{rows_to_update.count}\n"

        # migrate data
        update_th_qry = <<-SQL.squish
          UPDATE things AS t1
          SET metadata = jsonb_set(
              t1.metadata,
              ?,
              (
                SELECT t2.content->?
                from thing_translations as t2
                where t1.id = t2.thing_id
                  AND t2.locale = 'de'
              )
            )
          WHERE EXISTS (
              SELECT 1
              FROM thing_translations as t3
              WHERE t1.id = t3.thing_id
                AND t3.content->? IS NOT NULL
                AND t3.locale = 'de'#{' '}
                  #{'AND t1.template_name IN (?)' if templates.present?}
            )
        SQL
        sanitized_update_th_qry = ActiveRecord::Base.sanitize_sql_array([update_th_qry, "{#{field_to}}", field_from, field_from, templates])
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
          sanitized_remove_metadata_fields_qry = ActiveRecord::Base.sanitize_sql_array([remove_metadata_fields_qry, field_from, field_to, templates, field_from])
          deleted = ActiveRecord::Base.connection.exec_update(sanitized_remove_metadata_fields_qry)
          puts "Original values deleted: #{deleted}\n"
        end
      end
    end
  end
end
