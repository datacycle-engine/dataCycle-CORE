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

      # countries => country_codes - move
      desc 'update countries to corresponding country codes'
      task :country_to_country_codes, [:debug] => :environment do |_, _args|
        puts "starting to migrate countries to their corresponding country codes\n"

        # Count the amount of datasets, where not country_code is used but country for nationality
        rows_to_update = ActiveRecord::Base.connection.execute <<-SQL.squish
                SELECT 1 FROM classification_contents t1
                JOIN classifications AS t2 ON t1.classification_id = t2.id
                JOIN things AS t4 ON t1.content_data_id = t4.ID AND t4.template_name = 'Person'
                JOIN classifications as t3 ON t2.name = t3.description AND t3.external_key LIKE 'Ländercodes%'
                WHERE t1.relation = 'nationality'
        SQL
        puts "Datasets to migrate:  #{rows_to_update.count}\n"

        # Update the classification id in classification_contents from the old country to the new country_codes id
        rows_affected = ActiveRecord::Base.connection.execute <<-SQL.squish
                UPDATE classification_contents as t1
                SET classification_id = (
                  SELECT t3.id from classifications AS t2
                  JOIN classifications AS t3 ON t3.description = t2.name AND t3.external_key LIKE 'Ländercodes%'
                  WHERE t1.classification_id = t2.id
                )
                WHERE EXISTS (
                  SELECT 1 from things AS t4
                  WHERE t1.content_data_id = t4.ID AND t4.template_name = 'Person' AND t1.relation = 'nationality'
                )
        SQL
        puts "Datasets migrated:  #{rows_affected.cmd_tuples}\n"

        # Delete all of the old classifications
        if _args[:delete_old]
          puts "Deleting old classifications\n"
          deleted_rows = ActiveRecord::Base.connection.execute <<-SQL.squish
                  DELETE FROM classifications as c1
                  USING classifications as c2
                  WHERE
                    c2.description = c1.name
                    AND c2.external_key LIKE 'Ländercodes%'
                    AND c1.external_key LIKE 'Länder > %'
                    AND c1.external_key NOT LIKE 'Ländercodes >%'
          SQL
          puts "Amount of deleted rows: #{deleted_rows.cmd_tuples}\n"
        end
      end
    end
  end
end
