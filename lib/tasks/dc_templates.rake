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
      desc 'Calls all tasks that are needed for migration phase 1'
      task :migrate_phase_one, [:debug] => :environment do |_, _args|
        puts '-----------------------------'
        Rake::Task['dc:templates:migrations:data_definitions'].invoke

        puts '-----------------------------'
        Rake::Task['dc:templates:migrations:universal_classifications'].invoke

        puts '-----------------------------'
        mapping = DataCycleCore.data_definition_mapping['embedded_relations']
        puts 'no mapping for updating embedded_relations available' if mapping.blank?

        mapping.each do |key, value|
          puts "migrating embedded_relations for #{key}"
          from = value['from']
          to = value['to']
          templates = value['templates']

          params = [from, to]
          params << templates if templates.present?
          Rake::Task['dc:templates:migrations:embedded_relations'].invoke(*params)
          Rake::Task['dc:templates:migrations:embedded_relations'].reenable
        end

        puts '-----------------------------'
        mapping = DataCycleCore.data_definition_mapping['classification_contents']
        puts 'no mapping for updating classification contents available' if mapping.blank?

        mapping.each do |key, value|
          puts "migrating classification contents for #{key}"

          source_attribute = value['source_attribute']
          source_concept_scheme = value['source_concept_scheme']

          target_attribute = value['target_attribute']
          target_concept_scheme = value['target_concept_scheme']
          relation = value['relation']
          templates = value['templates']

          params = [source_attribute, source_concept_scheme, target_attribute, target_concept_scheme, relation]
          params << templates if templates.present?
          Rake::Task['dc:templates:migrations:update_classification_contents_based_on_similarity'].invoke(*params)
          Rake::Task['dc:templates:migrations:update_classification_contents_based_on_similarity'].reenable
        end

        puts '-----------------------------'
        mapping = DataCycleCore.data_definition_mapping['value_to_translated']
        puts 'no mapping for value->translated available' if mapping.blank?

        mapping.each do |key, value|
          puts "migrating value->translated for #{key}"
          from = value[:from]
          to = value[:to]
          operation = value[:operation]
          templates = value[:templates]

          params = [from, to, operation]
          params << templates if templates.present?
          Rake::Task['dc:templates:migrations:value_to_translated'].invoke(*params)
          Rake::Task['dc:templates:migrations:value_to_translated'].reenable
        end

        puts '-----------------------------'
        templates = DataCycleCore.data_definition_mapping['attributes_to_additional_information']['templates']
        puts 'no templates for attributes_to_additional_information available' if templates.blank?

        Rake::Task['dc:templates:migrations:attributes_to_additional_information'].invoke(templates)
        puts '-----------------------------'

        Rake::Task['dc:templates:migrations:migrate_contact_info_url']
        puts '-----------------------------'
      end

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

        if mappings.blank?
          puts 'no mappings found \n'
          exit(-1)
        end

        mappings.each do |key, value|
          if key == value
            puts "skip mapping #{key}: #{value} - key equals value"
            next
          end

          thing_templates = DataCycleCore::ThingTemplate.where(template_name: [key, value])
          if thing_templates.count != 2
            puts "skip mapping #{key}: #{value} - key (#{key}) or value (#{value}) not known in thing_templates"
            next
          end

          things = DataCycleCore::Thing.where(template_name: key)
          puts "Changing things template_name #{key} to #{value} for: #{things.count} rows"
          things_progressbar = ProgressBar.create(total: things.count, format: '%t |%w>%i| %a - %c/%C', title: "#{key} => #{value}")
          things.find_each do |thing|
            thing.update(template_name: value, cache_valid_since: nil)
            things_progressbar.increment
          end

          old_things_count = DataCycleCore::Thing.where(template_name: value).count
          new_things_count = DataCycleCore::Thing.where(template_name: key).count
          puts "things with template_name new template_name #{value}: #{old_things_count} rows"
          puts "things with template_name old template_name #{key}: #{new_things_count} rows"
        end
      end

      # updates relation to universal_classification, for specified list of origin_relations
      # updates those, who do not already have universal_classification assigned
      # deletes those, who have
      task :universal_classifications, [:debug] => :environment do |_, _args|
        puts "migrate classifications to universal classifications\n"
        if DataCycleCore.data_definition_mapping['universal_classifications'].blank?
          puts 'no mappings found'
          exit(-1)
        end
        classifications = DataCycleCore.data_definition_mapping['universal_classifications']
        ap classifications

        puts 'start updating to universal_classifications'
        ActiveRecord::Base.connection.execute <<-SQL.squish
          SET LOCAL statement_timeout = 0;
          WITH rows_to_update AS (
            SELECT content_data_id, classification_id
            FROM classification_contents
            WHERE relation IN ('#{classifications.join("','")}')
            AND NOT EXISTS (
                SELECT 1 FROM classification_contents AS cc
                WHERE cc.relation = 'universal_classifications'
                AND cc.content_data_id = classification_contents.content_data_id
                AND cc.classification_id = classification_contents.classification_id
            )
          )
          UPDATE classification_contents
          SET relation = 'universal_classifications'
          WHERE (content_data_id, classification_id) IN (SELECT content_data_id, classification_id FROM rows_to_update);
        SQL

        puts 'now histories'
        ActiveRecord::Base.connection.execute <<-SQL.squish
          SET LOCAL statement_timeout = 0;
          WITH rows_to_update AS (
            SELECT cch1.content_data_history_id, cch1.classification_id
            FROM classification_content_histories AS cch1
            WHERE cch1.relation IN ('#{classifications.join("','")}')
              AND NOT EXISTS (
                SELECT 1 FROM
                  classification_content_histories AS cch2
                  WHERE cch1.content_data_history_id = cch2.content_data_history_id
                  AND cch1.classification_id = cch2.classification_id
                  AND cch2.relation = 'universal_classifications'
                )
          )
          UPDATE classification_content_histories
          SET relation = 'universal_classifications'
          WHERE (content_data_history_id, classification_id) IN (SELECT content_data_history_id, classification_id FROM rows_to_update);
        SQL

        puts 'delete rows, where a dataset with universal_classification already existed'
        ActiveRecord::Base.connection.execute <<-SQL.squish
          DELETE FROM classification_contents WHERE relation IN ('#{classifications.join("','")}');
          DELETE FROM classification_content_histories WHERE relation IN ('#{classifications.join("','")}');
        SQL
      end

      desc 'changes relation_a from old value to new value for given templates'
      task :embedded_relations, [:from, :to, :templates, :debug] => :environment do |_, args|
        old_relation = args.from
        new_relation = args.to
        templates = args.templates&.split('|')

        if old_relation.present? && new_relation.present?
          puts "migrate content_contents to new relations from #{old_relation} to #{new_relation}\n"

          update_cc_query = <<~SQL.squish
            UPDATE content_contents AS cc
            SET relation_a = ?
            WHERE EXISTS (
              SELECT 1 FROM things as t
              WHERE cc.content_a_id = t.id
                AND cc.relation_a = ?
                #{" AND t.content_type = 'entity'" if templates.blank?}
                #{' AND t.template_name IN (?)' if templates.present?}
            )
          SQL

          update_cch_query = <<~SQL.squish
            UPDATE content_content_histories AS cch
            SET relation_a = ?
            WHERE EXISTS (
              SELECT 1 FROM thing_histories as th
              JOIN things as t ON th.thing_id = t.id
              WHERE cch.content_a_history_id = th.id
                AND cch.relation_a = ?
                #{" AND th.content_type = 'entity'" if templates.blank?}
                #{' AND th.template_name IN (?)' if templates.present?}
            )
          SQL

          query_args = [new_relation, old_relation]
          query_args << templates if templates.present?
          sanitized_update_cc = ActiveRecord::Base.send(:sanitize_sql_array, [update_cc_query, *query_args])
          sanitized_update_cc_history = ActiveRecord::Base.send(:sanitize_sql_array, [update_cch_query, *query_args])

          ActiveRecord::Base.connection.exec_update(sanitized_update_cc)
          ActiveRecord::Base.connection.exec_update(sanitized_update_cc_history)

          puts "migrated #{old_relation} to #{new_relation}"
        else
          puts "Missing parameters\n"
        end
      end

      # switches classification_id in classification_contents according to their classification_tree_labels
      desc 'changes classification_id for things according to old and new tree_label'
      task :update_classification_contents_based_on_similarity, [:source_attribute, :source_concept_scheme, :target_attribute, :target_concept_scheme, :relation, :templates, :debug] => :environment do |_, args|
        puts "Starting to migrate countries to their corresponding country codes\n"
        from_concept_scheme_name = args.source_concept_scheme
        to_concept_scheme_name = args.target_concept_scheme
        templates = args.templates&.split('|')
        relation = args.relation

        attribute_mapping = {
          'name' => 'internal_name',
          'description' => "description_i18n->>'de'"
        }

        source_attribute = attribute_mapping[args.source_attribute]
        target_attribute = attribute_mapping[args.target_attribute]

        if source_attribute.present? && target_attribute.present? && from_concept_scheme_name.present? && to_concept_scheme_name.present? && relation.present?

          # Count the amount of datasets that need to be updated
          select_cc = <<-SQL.squish
          SELECT co2.classification_id AS new_classification_id, cc.id
          FROM classification_contents AS cc
            JOIN concepts AS co ON cc.classification_id = co.classification_id
            JOIN concept_schemes AS cs ON cs.id = co.concept_scheme_id
              AND cs.name = ?
            JOIN concepts AS co2 ON co2.#{target_attribute} = co.#{source_attribute}
            JOIN concept_schemes AS cs2 ON cs2.id = co2.concept_scheme_id
              AND cs2.name = ?
            JOIN things AS th ON th.id = cc.content_data_id
              #{" AND th.content_type = 'entity'" if templates.blank?}
              #{' AND th.template_name IN (?)' if templates.present?}
          WHERE cc.relation = ?
          SQL

          query_args = [from_concept_scheme_name, to_concept_scheme_name]
          query_args << templates if templates.present?
          query_args << relation
          sanitized_select_cc = ActiveRecord::Base.send(:sanitize_sql_array, [select_cc, *query_args])
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
                  JOIN concepts AS co2 ON co2.#{target_attribute} = co.#{source_attribute}
                  JOIN concept_schemes AS cs2 ON cs2.id = co2.concept_scheme_id
                    AND cs2.name = ?
                  JOIN things AS th ON th.id = cc.content_data_id
                    #{" AND th.content_type = 'entity'" if templates.blank?}
                    #{' AND th.template_name IN (?)' if templates.present?}
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

          sanitized_update_cc = ActiveRecord::Base.send(:sanitize_sql_array, [update_cc, *query_args])
          rows_updated = ActiveRecord::Base.connection.exec_update(sanitized_update_cc)
          puts "Datasets migrated:  #{rows_updated}\n"
        else
          puts 'Parameters Missing'
        end
      end

      # value => translated_value (copy vs move)
      # if no templates are given, all templates for content_type = entity are updated
      desc 'value => translated (copy/move) | templates as one | seperated string'
      task :value_to_translated, [:from, :to, :operation, :templates, :debug] => :environment do |_, args|
        field_from = args.from
        field_to = args.to
        operation = args.operation
        templates = args.templates&.split('|')
        puts "migrate #{field_from} to translated #{field_to} | Operation: #{operation}\n"

        if field_from.present? && field_to.present? && operation.present?
          # count how many rows should be affected by the migration
          select_th_qry = <<-SQL.squish
          SELECT 1
          FROM things AS t1
            JOIN thing_translations ON t1.id = thing_translations.thing_id
          WHERE t1.metadata->? IS NOT NULL
            #{" AND t1.content_type = 'entity'" if templates.blank?}
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
                      #{" AND th.content_type = 'entity'" if templates.blank?}
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
          if operation == 'move'
            remove_metadata_fields_qry = <<-SQL.squish
            UPDATE things
            SET metadata = metadata - ?
            WHERE things.metadata->? IS NOT NULL
              #{" AND things.content_type = 'entity'" if templates.blank?}
              #{' AND things.template_name IN (?)' if templates.present?}
            SQL

            query_args = [field_from, field_from]
            query_args << templates if templates.present?
            sanitized_remove_metadata_fields_qry = ActiveRecord::Base.sanitize_sql_array([remove_metadata_fields_qry, *query_args])
            deleted = ActiveRecord::Base.connection.exec_update(sanitized_remove_metadata_fields_qry)
            puts "Original values deleted: #{deleted}\n"
          end
        else
          puts "Missing parameters\n"
        end
      end

      # translated => simple_value (copy/move)
      desc 'translated => value (copy/move) | templates as one | seperated string'
      task :translated_to_value, [:from, :to, :operation, :templates, :debug] => :environment do |_, args|
        field_from = args.from
        field_to = args.to
        operation = args.operation
        templates = args.templates&.split('|')
        puts "migrate translated #{field_from} to #{field_to} | Operation: #{operation}\n"

        if field_from.present? && field_to.present? && operation.present?

          # count how many rows should be affected by the migration
          select_tt_qry = <<-SQL.squish
          SELECT 1
          FROM thing_translations AS t1
            JOIN things AS t2 ON t1.thing_id = t2.id
          WHERE t1.content->? IS NOT NULL
            AND t1.locale = 'de'#{' '}
              #{" AND t2.content_type = 'entity'" if templates.blank?}
              #{'AND t2.template_name IN (?)' if templates.present?}
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
            #{" AND th.content_type = 'entity'" if templates.blank?}
            #{' AND th.template_name IN (?)' if templates.present?}
          SQL

          query_args = ["{#{field_to}}", field_from, field_from]
          query_args << templates if templates.present?
          sanitized_update_th_qry = ActiveRecord::Base.sanitize_sql_array([update_th_qry, *query_args])
          rows_updated = ActiveRecord::Base.connection.exec_update(sanitized_update_th_qry)
          puts "Datasets migrated:  #{rows_updated}\n"

          # remove old fields from metadata json, if operation equals move
          if operation == 'move'
            remove_metadata_fields_qry = <<-SQL.squish
            UPDATE thing_translations t1
            SET content = content - ?
            WHERE EXISTS (
                SELECT 1 FROM things as t2
                WHERE t1.thing_id = t2.id
                  AND t2.metadata->? IS NOT NULL
                  #{" AND t2.content_type = 'entity'" if templates.blank?}
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
        else
          puts "Missing parameters\n"
        end
      end

      desc 'migrate attributes for which mapping in \'data_definition_mapping.yml\' is provided to additional_information'
      task :attributes_to_additional_information, [:templates] => :environment do |_, args|
        puts "migrating attributes to additional_information for templates #{args.templates}"
        template_names = args.templates&.split('|')

        if template_names.blank?
          puts 'no templates found \n'
          exit(-1)
        end

        attributes_mapping = DataCycleCore.data_definition_mapping['attributes_to_additional_information']
        if attributes_mapping.blank?
          puts 'no mappings found \n'
          exit(-1)
        end

        attributes_mapping.delete('templates')
        count = 0

        template_names.each do |template_name|
          contents = DataCycleCore::Thing.where(template_name:, external_source_id: nil)
          progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: template_name)

          contents.find_each do |content|
            content.translated_locales.each do |locale|
              I18n.with_locale(locale) do
                additional_information = content.to_h_partial('additional_information')&.[]('additional_information') || []
                new_information = []

                attributes_mapping.each do |mapping_type, mappings|
                  mappings.each_key do |info_type_mapping_key|
                    value = content.try(info_type_mapping_key)
                    next if value.blank? || additional_information.any? do |v|
                      DataCycleCore::MasterData::DataConverter.string_to_string(
                        v['description']&.strip_tags
                      ) ==
                      DataCycleCore::MasterData::DataConverter.string_to_string(value&.strip_tags)
                    end

                    new_information.push(
                      'name' => I18n.t(
                        "import.outdoor_active.place.#{info_type_mapping_key}",
                        locale: locale.to_s.in?(['de', 'en']) ? locale : 'de'
                      ),
                      'description' => value,
                      'type_of_information' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(
                        mapping_type == 'internal' ? 'Informationstypen' : 'Externe Informationstypen',
                        info_type_mapping_key
                      )
                    )
                  end
                end

                next if new_information.blank?

                additional_information.each { |a| a.slice!('id') }
                additional_information.concat(new_information)

                content.set_data_hash(data_hash: { additional_information: })

                count += 1
              end
            end

            progressbar.increment
          end
        end

        puts "updated #{count} things"
      end

      desc 'moves the url from contact_info to the field contact_url in contact_info'
      task :migrate_contact_info_url, [:debug] => :environment do |_, _args|
        puts "move contact_info.url to contact_info.contact_url\n"

        # count how many rows should be affected by the migration
        select_th_qry = <<-SQL.squish
          SELECT 1
          FROM thing_translations
          WHERE jsonb_path_exists(content, '$.contact_info.url')

        SQL
        rows_to_update = ActiveRecord::Base.connection.select_all(select_th_qry)
        puts "Values to move:  #{rows_to_update.count}\n"

        # copy url to contact_url
        update_tt_qry = <<-SQL.squish
          UPDATE thing_translations
          SET content = jsonb_set(
            content,
            '{contact_info,contact_url}',
            content->'contact_info'->'url'
          )
          WHERE content->'contact_info' IS NOT NULL
        SQL
        rows_updated = ActiveRecord::Base.connection.exec_update(update_tt_qry)
        puts "Values moved: #{rows_updated}\n"

        # delete old data
        update_tt_qry = <<-SQL.squish
        UPDATE thing_translations t
          SET content = jsonb_set(
            content,
            '{contact_info}',
            (content->'contact_info') - 'url'
          )
          WHERE t.content->'contact_info' IS NOT NULL
        SQL
        ActiveRecord::Base.connection.exec_update(update_tt_qry)

        rows_to_update = ActiveRecord::Base.connection.select_all(select_th_qry)
        puts "Remaining values to move:  #{rows_to_update.count}\n"
      end
    end
  end
end
