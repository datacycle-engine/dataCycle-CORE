# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :refactor do
    desc 'migrate all content_tables to things'
    task migrate_content_to_things: :environment do
      puts 'migrating all content_tables to things'

      print_box('Stage 1 - Organizations')
      Rake::Task['data_cycle_core:refactor:migrate_organizations_to_things'].invoke

      print_box('Stage 2 - Persons')
      Rake::Task['data_cycle_core:refactor:migrate_persons_to_things'].invoke

      print_box('Stage 3 - Events')
      Rake::Task['data_cycle_core:refactor:migrate_events_to_things'].invoke

      print_box('Stage 4 - Places')
      Rake::Task['data_cycle_core:refactor:migrate_places_to_things'].invoke

      print_box('Stage 5 - Creative Works')
      Rake::Task['data_cycle_core:refactor:migrate_creative_works_to_things'].invoke

      print_box('bonus stage - templates')
      Rake::Task['data_cycle_core:refactor:migrate_all_templates'].invoke
    end

    desc 'migrate organizations - executes all migration tasks'
    task migrate_organizations_to_things: :environment do
      ActiveRecord::Base.transaction do
        temp = Time.zone.now
        puts "BEGIN: (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

        puts 'update references'
        update_references('Organization')

        puts 'migrate data'
        puts '--> things'
        sql = <<-SQL
          INSERT INTO things (
            id, metadata,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, metadata,
            template_name, schema, template,
            NULL,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM organizations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_translations'
        sql = <<-SQL
          INSERT INTO thing_translations (
            thing_id, locale,
            content,
            name, description,
            created_at, updated_at
          )
          SELECT
            organization_id, locale,
            content - 'legal_name,
            content ->> 'legal_name',
            description,
            created_at, updated_at
          FROM organization_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_histories'
        sql = <<-SQL
          INSERT INTO thing_histories (
            id, thing_id, metadata,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, organization_id, metadata,
            template_name, schema, template,
            NULL,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM organization_histories
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_history_translations'
        sql = <<-SQL
          INSERT INTO thing_history_translations (
            thing_history_id, locale,
            content,
            name,
            description,
            history_valid,
            created_at, updated_at
          )
          SELECT
            organization_history_id, locale,
            content - 'legal_name',
            content ->> 'legal_name',
            description,
            history_valid,
            created_at, updated_at
          FROM organization_history_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts 'END'
        puts "--> MIGRATION COMPLETE #{(Time.zone.now - temp).round(3)}"
      end
    end

    desc 'migrate persons - executes all migration tasks'
    task migrate_persons_to_things: :environment do
      ActiveRecord::Base.transaction do
        temp = Time.zone.now
        puts "BEGIN: (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

        puts 'update references'
        update_references('Person')

        puts 'migrate data'
        puts '--> things'
        sql = <<-SQL
          INSERT INTO things (
            id, metadata,
            given_name, family_name,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, metadata,
            given_name, family_name,
            template_name, schema, template,
            concat(given_name, ' ', family_name),
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM persons
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_translations'
        sql = <<-SQL
          INSERT INTO thing_translations (
            thing_id, locale,
            content,
            name, description,
            created_at, updated_at
          )
          SELECT
            person_id, locale,
            content,
            headline,
            description,
            created_at, updated_at
          FROM person_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_histories'
        sql = <<-SQL
          INSERT INTO thing_histories (
            id, thing_id, metadata,
            given_name, family_name,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, person_id, metadata,
            given_name, family_name,
            template_name, schema, template,
            concat(given_name, ' ', family_name),
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM person_histories
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_history_translations'
        sql = <<-SQL
          INSERT INTO thing_history_translations (
            thing_history_id, locale,
            content,
            name,
            description,
            history_valid,
            created_at, updated_at
          )
          SELECT
            person_history_id, locale,
            content,
            headline,
            description,
            history_valid,
            created_at, updated_at
          FROM person_history_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts 'END'
        puts "--> MIGRATION COMPLETE #{(Time.zone.now - temp).round(3)}"
      end
    end

    desc 'migrate events - executes all migration tasks'
    task migrate_events_to_things: :environment do
      ActiveRecord::Base.transaction do
        temp = Time.zone.now
        puts "BEGIN: (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

        puts 'update references'
        update_references('Event')

        puts 'migrate data'
        puts '--> things'
        sql = <<-SQL
          INSERT INTO things (
            id, metadata,
            start_date, end_date,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, metadata,
            start_date, end_date,
            template_name, schema, template,
            NULL,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM events
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_translations'
        sql = <<-SQL
          INSERT INTO thing_translations (
            thing_id, locale,
            content,
            name,
            description,
            created_at, updated_at
          )
          SELECT
            event_id, locale,
            content - 'name',
            content ->> 'name',
            description,
            created_at, updated_at
          FROM event_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_histories'
        sql = <<-SQL
          INSERT INTO thing_histories (
            id, thing_id, metadata,
            start_date, end_date,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, event_id, metadata,
            start_date, end_date,
            template_name, schema, template,
            NULL,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM event_histories
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_history_translations'
        sql = <<-SQL
          INSERT INTO thing_history_translations (
            thing_history_id, locale,
            content,
            name,
            description,
            history_valid,
            created_at, updated_at
          )
          SELECT
            event_history_id, locale,
            content - 'name',
            content ->> 'name',
            description,
            history_valid,
            created_at, updated_at
          FROM event_history_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts 'END'
        puts "--> MIGRATION COMPLETE #{(Time.zone.now - temp).round(3)}"
      end
    end

    desc 'migrate places - executes all migration tasks'
    task migrate_places_to_things: :environment do
      ActiveRecord::Base.transaction do
        temp = Time.zone.now
        puts "BEGIN: (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

        puts 'update references'
        update_references('Place')

        puts 'migrate data'
        puts '--> things'
        sql = <<-SQL
          INSERT INTO things (
            id, metadata,
            longitude, latitude, elevation, location, line,
            address_locality, street_address, postal_code, address_country,
            fax_number, telephone, email,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, metadata,
            longitude, latitude, elevation, location, line,
            address_locality, street_address, postal_code, address_country,
            fax_number, telephone, email,
            template_name, schema, template,
            NULL,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM places
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_translations'
        sql = <<-SQL
          INSERT INTO thing_translations (
            thing_id, locale,
            content,
            name,
            description,
            created_at, updated_at
          )
          SELECT
            place_id, locale,
            content,
            name,
            description,
            created_at, updated_at
          FROM place_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_histories'
        sql = <<-SQL
          INSERT INTO thing_histories (
            id, thing_id, metadata,
            longitude, latitude, elevation, location, line,
            address_locality, street_address, postal_code, address_country,
            fax_number, telephone, email,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, place_id, metadata,
            longitude, latitude, elevation, location, line,
            address_locality, street_address, postal_code, address_country,
            fax_number, telephone, email,
            template_name, schema, template,
            NULL,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM place_histories
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_history_translations'
        sql = <<-SQL
          INSERT INTO thing_history_translations (
            thing_history_id, locale,
            content,
            name,
            description,
            history_valid,
            created_at, updated_at
          )
          SELECT
            place_history_id, locale,
            content,
            name,
            description,
            history_valid,
            created_at, updated_at
          FROM place_history_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        sql_query = <<-EOS
          UPDATE content_contents SET
          	relation_a = 'content_location'
          where relation_a = 'location';
        EOS
        ActiveRecord::Base.connection.exec_query(ActiveRecord::Base.send(:sanitize_sql_for_conditions, sql_query))
        sql_query = <<-EOS
          UPDATE content_content_histories SET
          	relation_a = 'content_location'
          where relation_a = 'location';
        EOS
        ActiveRecord::Base.connection.exec_query(ActiveRecord::Base.send(:sanitize_sql_for_conditions, sql_query))

        puts 'END'
        puts "--> MIGRATION COMPLETE #{(Time.zone.now - temp).round(3)}"
      end
    end

    desc 'migrate creative_works - executes all migration tasks'
    task migrate_creative_works_to_things: :environment do
      ActiveRecord::Base.transaction do
        temp = Time.zone.now
        puts "BEGIN: (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

        puts 'update references'
        update_references('CreativeWork')

        puts 'migrate data'
        puts '--> things'
        puts '    prepare creative_works'
        # prepare creative_works, as external_keys are not unique
        sql = <<-SQL
          UPDATE creative_works AS cw SET
            external_key = cw.external_key || ' - image'
          WHERE cw.id IN (
            SELECT id FROM creative_works
            where external_key ILIKE 'Xamoom -%'
          );
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '    copy data'
        sql = <<-SQL
          INSERT INTO things (
            id, is_part_of, metadata,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, is_part_of, metadata,
            template_name, schema, template,
            NULL,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM creative_works
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_translations'
        sql = <<-SQL
          INSERT INTO thing_translations (
            thing_id, locale,
            content,
            name,
            description,
            created_at, updated_at
          )
          SELECT
            creative_work_id, locale,
            content,
            headline,
            description,
            created_at, updated_at
          FROM creative_work_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_histories'
        sql = <<-SQL
          INSERT INTO thing_histories (
            id, thing_id, is_part_of, metadata,
            template_name, schema, template,
            internal_name,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          )
          SELECT
            id, creative_work_id, is_part_of, metadata,
            template_name, schema, template,
            NULL,
            external_source_id, external_key,
            created_by, updated_by, deleted_by,
            seen_at, created_at, updated_at, deleted_at
          FROM creative_work_histories
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> thing_history_translations'
        sql = <<-SQL
          INSERT INTO thing_history_translations (
            thing_history_id, locale,
            content,
            name,
            description,
            history_valid,
            created_at, updated_at
          )
          SELECT
            creative_work_history_id, locale,
            content,
            headline,
            description,
            history_valid,
            created_at, updated_at
          FROM creative_work_history_translations
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts '--> cleanup attributes'
        sql = <<-SQL
          UPDATE thing_translations AS tt SET
          	name = tt.content ->> 'name',
            content = tt.content - 'name'
          WHERE tt.thing_id IN (
            SELECT id from things
            WHERE template = false
            AND template_name = 'Textblock'
          );
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        sql = <<-SQL
          UPDATE thing_translations AS tt SET
          	content = jsonb_insert((tt.content - 'name'), '{link_name}', (tt.content ->> 'name')::jsonb)
          WHERE (tt.content ->> 'name') NOT IN (NULL, '', ' ')
          AND tt.thing_id IN (
            SELECT id from things
            WHERE template = false
            AND template_name IN ('Angebot', 'Artikel', 'Rezept', 'Website')
          );
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        sql = <<-SQL
          UPDATE thing_history_translations AS tt SET
          	name = tt.content ->> 'name',
            content = tt.content - 'name'
          WHERE tt.thing_history_id IN (
            SELECT id from thing_histories
            WHERE template = false
            AND template_name = 'Textblock'
          );
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        sql = <<-SQL
          UPDATE thing_history_translations AS tt SET
          	content = jsonb_insert((tt.content - 'name'), '{link_name}', (tt.content ->> 'name')::jsonb)
          WHERE (tt.content ->> 'name') NOT IN (NULL, '', ' ')
          AND tt.thing_history_id IN (
            SELECT id from thing_histories
            WHERE template = false
            AND template_name IN ('Angebot', 'Artikel', 'Rezept', 'Website')
          );
        SQL
        ActiveRecord::Base.connection.exec_query(sql)

        puts 'END'
        puts "--> MIGRATION COMPLETE #{(Time.zone.now - temp).round(3)}"
      end
    end

    private

    def update_references(name)
      raise unless ['Event', 'Person', 'CreativeWork', 'Place', 'Organization'].include?(name)

      DataCycleCore::ContentContent.where(content_a_type: "DataCycleCore::#{name}").update_all(content_a_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent.where(content_b_type: "DataCycleCore::#{name}").update_all(content_b_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent::History.where(content_a_history_type: "DataCycleCore::#{name}").update_all(content_a_history_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent::History.where(content_b_history_type: "DataCycleCore::#{name}").update_all(content_b_history_type: 'DataCycleCore::Thing')
      DataCycleCore::ContentContent::History.where(content_a_history_type: "DataCycleCore::#{name}::History").update_all(content_a_history_type: 'DataCycleCore::Thing::History')
      DataCycleCore::ContentContent::History.where(content_b_history_type: "DataCycleCore::#{name}::History").update_all(content_b_history_type: 'DataCycleCore::Thing::History')

      update_content_relations

      DataCycleCore::ClassificationContent.where(content_data_type: "DataCycleCore::#{name}").update_all(content_data_type: 'DataCycleCore::Thing')
      DataCycleCore::ClassificationContent::History.where(content_data_history_type: "DataCycleCore::#{name}::History").update_all(content_data_history_type: 'DataCycleCore::Thing::History')

      DataCycleCore::Search.where(content_data_type: "DataCycleCore::#{name}").update_all(content_data_type: 'DataCycleCore::Thing')
      DataCycleCore::WatchListDataHash.where(hashable_type: "DataCycleCore::#{name}").update_all(hashable_type: 'DataCycleCore::Thing')
      DataCycleCore::Subscription.where(subscribable_type: "DataCycleCore::#{name}").update_all(subscribable_type: 'DataCycleCore::Thing')
      DataCycleCore::DataLink.where(item_type: "DataCycleCore::#{name}").update_all(item_type: 'DataCycleCore::Thing')
    end

    def update_content_relations
      ActiveRecord::Base.transaction do
        connection = ActiveRecord::Base.connection
        sql_query = <<-SQL
          UPDATE content_contents as new_cc SET
            content_a_id = content_contents.content_b_id,
            content_b_id = content_contents.content_a_id,
            content_a_type = content_contents.content_b_type,
            content_b_type = content_contents.content_a_type,
            relation_a = content_contents.relation_b,
            relation_b = content_contents.relation_a,
            order_a = content_contents.order_b,
            order_b = content_contents.order_a
          FROM content_contents
          Where new_cc.id = content_contents.id
          AND content_contents.relation_b <> NULL
          AND content_contents.relation_b <> ''
          AND content_contents.content_a_type >= content_contents.content_b_type;
        SQL
        connection.exec_query(ActiveRecord::Base.send(:sanitize_sql_for_conditions, sql_query))
        sql_query = <<-SQL
          UPDATE content_content_histories as new_cc SET
            content_a_history_id = content_content_histories.content_b_history_id,
            content_b_history_id = content_content_histories.content_a_history_id,
            content_a_history_type = content_content_histories.content_b_history_type,
            content_b_history_type = content_content_histories.content_a_history_type,
            relation_a = content_content_histories.relation_b,
            relation_b = content_content_histories.relation_a,
            order_a = content_content_histories.order_b,
            order_b = content_content_histories.order_a
          FROM content_content_histories
          Where new_cc.id = content_content_histories.id
          AND content_content_histories.relation_b <> NULL
          AND content_content_histories.relation_b <> ''
          AND content_content_histories.content_a_history_type >= content_content_histories.content_b_history_type;
        SQL
        connection.exec_query(ActiveRecord::Base.send(:sanitize_sql_for_conditions, sql_query))
      end
    end

    def print_box(name)
      width = name.size + 8
      puts '=' * width
      puts '==> ' + name.upcase + ' <=='
      puts '=' * width
    end
  end
end
