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
      task :value_to_translated, [:from, :to, :operation, :templates, :debug] => :environment do |_, _args|
        field_from = _args[:from]
        field_to = _args[:to]
        templates = _args[:templates].split.map { |word| "'#{word}'" }.join(',')
        puts "migrate #{field_from} to translated #{field_to} for templates #{templates} | Operation: #{_args[:operation]}\n"

        # count how many rows should be affected by the migration
        rows_to_update = ActiveRecord::Base.connection.execute <<-SQL.squish
                 SELECT 1
                   FROM things AS t1
                   JOIN thing_translations ON t1.id = thing_translations.thing_id
                   WHERE t1.metadata->'#{field_from}' IS NOT NULL
                   #{"AND t1.template_name IN (#{templates})" if templates.present?}
        SQL
        puts "Datasets to migrate:  #{rows_to_update.count}\n"

        # migrate data
        rows_updated = ActiveRecord::Base.connection.execute <<-SQL.squish
                 UPDATE thing_translations AS t1
                 SET content = jsonb_set(
                   t1.content,
                   '{#{field_to}}',
                   (SELECT things.metadata->'#{field_from}' from things where things.id = t1.thing_id)
                 )
                 WHERE EXISTS (
                     SELECT 1
                     FROM things
                     WHERE things.id = t1.thing_id AND things.metadata->'#{field_from}' IS NOT NULL
                     #{"AND things.template_name IN (#{templates})" if templates.present?}
                 );
        SQL
        puts "Datasets migrated:  #{rows_updated.cmd_tuples}\n"

        # remove old fields from metadata json, if operation equals move
        if _args[:operation] == 'move'
          count_deleted = ActiveRecord::Base.connection.execute <<-SQL.squish
                   UPDATE things
                   SET metadata = metadata - '#{field_from}'
                   WHERE things.metadata->'#{field_from}' IS NOT NULL
          SQL
          puts "Original values deleted: #{count_deleted.cmd_tuples}\n"
        end
      end

      # Todo - 1:n relation - discuss which value should be moved/copied
      # translated => simple_value (copy/move)
      desc 'translated => value (copy/move)'
      task :translated_to_value, [:from, :to, :locale, :operation, :templates, :debug] => :environment do |_, _args|
        field_from = _args[:from]
        field_to = _args[:to]
        locale = _args[:locale]
        templates = _args[:templates].split.map { |word| "'#{word}'" }.join(',')
        puts "migrate translated #{field_from} to #{field_to} for templates #{templates} | Operation: #{_args[:operation]}\n"

        # count how many rows should be affected by the migration
        rows_to_update = ActiveRecord::Base.connection.execute <<-SQL.squish
                 SELECT 1
                   FROM thing_translations AS t1
                   JOIN things AS t2 ON t1.thing_id = t2.id
                   WHERE t1.content->'#{field_from}' IS NOT NULL
                   AND t1.locale = '#{locale}'
                   #{"AND t2.template_name IN (#{templates})" if templates.present?}
        SQL
        puts "Datasets to migrate:  #{rows_to_update.count}\n"

        # migrate data
        rows_updated = ActiveRecord::Base.connection.execute <<-SQL.squish
                 UPDATE things AS t1
                 SET metadata = jsonb_set(
                   t1.metadata,
                   '{#{field_to}}',
                   (SELECT t2.content->'#{field_from}' from thing_translations as t2 where t1.id = t2.thing_id AND t2.locale = '#{locale}')
                 )
                 WHERE EXISTS (
                     SELECT 1
                     FROM thing_translations as t3
                     WHERE t1.id = t3.thing_id
                     AND t3.content->'#{field_from}' IS NOT NULL
                     AND t3.locale = '#{locale}'
                     #{"AND t1.template_name IN (#{templates})" if templates.present?}
                 );
        SQL
        puts "Datasets migrated:  #{rows_updated.cmd_tuples}\n"

        # remove old fields from metadata json, if operation equals move
        if _args[:operation] == 'move'
          count_deleted = ActiveRecord::Base.connection.execute <<-SQL.squish
                   UPDATE thing_translations t1
                   SET content = content - '#{field_from}'
                   WHERE EXISTS (
                     SELECT 1 FROM things as t2
                     WHERE t1.thing_id = t2.id
                     AND t2.metadata->'#{field_to}' IS NOT NULL
                   )
                   AND t1.content->'#{field_from}' IS NOT NULL

          SQL
          puts "Original values deleted: #{count_deleted.cmd_tuples}\n"
        end
      end
    end
  end
end
