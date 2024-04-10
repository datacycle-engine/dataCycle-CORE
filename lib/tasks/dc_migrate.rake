# frozen_string_literal: true

require 'rake_helpers/content_helper'

namespace :dc do
  namespace :migrate do
    desc 'move external_source_id and external_key from things to external_system_syncs'
    task :external_source_to_system, [:external_system_or_stored_filter_id] => :environment do |_, args|
      external_system_or_stored_filter_id = args.external_system_or_stored_filter_id

      abort('ExternalSystem- or StoredFilter-Id missing!') if external_system_or_stored_filter_id.blank?

      stored_filter = DataCycleCore::StoredFilter.find_by(id: external_system_or_stored_filter_id)
      external_system = DataCycleCore::ExternalSystem.find_by(id: external_system_or_stored_filter_id)

      abort('ExternalSystem or StoredFilter not found!') if stored_filter.nil? && external_system.nil?

      stored_filter = DataCycleCore::StoredFilter.new if stored_filter.nil?
      query = stored_filter.apply(skip_ordering: true)
      query = query.external_system(external_system.id, 'import') if external_system.present?

      raw_sql = <<-SQL.squish
        WITH RECURSIVE
          content_dependencies AS (
            SELECT
              t.id
            FROM
              things AS t
            WHERE
              t.id IN (#{query.query.except(:order).select(:id).to_sql})
              AND t.content_type != 'embedded'
            UNION
            SELECT
              t.id
            FROM
              content_dependencies,
              content_content_links
              JOIN things AS t ON t.id = content_content_links.content_b_id
              AND t.content_type = 'embedded'
            WHERE
              content_content_links.content_a_id = content_dependencies.id
              AND content_content_links.relation IS NOT NULL
          )
        SELECT
          id
        FROM
          content_dependencies
      SQL

      embeddeds = DataCycleCore::Thing.where("things.id IN (#{raw_sql})").where(content_type: 'embedded')
      progressbar1 = ProgressBar.create(total: embeddeds.size, format: '%t |%w>%i| %a - %c/%C', title: 'MIGRATING: embeddeds')

      embeddeds.each do |embedded|
        embedded.external_source_to_external_system_syncs('duplicate')

        progressbar1.increment
      end

      contents = query.query.except(:order)

      schedules = DataCycleCore::Schedule.where(thing_id: contents.select(:id))
      puts "MIGRATING: schedules (#{schedules.size})..."
      schedules.update_all(external_source_id: nil, external_key: nil)

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'MIGRATING: things')

      contents.each do |content|
        content.external_source_to_external_system_syncs('duplicate')

        progressbar.increment
      end

      puts 'MIGRATION SUCCESSFUL'
    end

    desc 'remove external_source_id and external_key from things to external_system_syncs'
    task :remove_external_source_from_classifications, [:external_system_id] => :environment do |_, args|
      external_system_id = args.external_system_id

      abort('ExternalSystemId missing!') if external_system_id.blank?

      classifications = DataCycleCore::Classification.where(external_source_id: external_system_id)
      puts "MIGRATING: classifications (#{classifications.size})..."
      classifications.update_all(external_source_id: nil, external_key: nil)

      classification_trees = DataCycleCore::ClassificationTreeLabel.where(external_source_id: external_system_id)
      puts "MIGRATING: classification_trees (#{classification_trees.size})..."
      classification_trees.update_all(external_source_id: nil)

      classification_groups = DataCycleCore::ClassificationGroup.where(external_source_id: external_system_id)
      puts "MIGRATING: classification_groups (#{classification_groups.size})..."
      classification_groups.update_all(external_source_id: nil)

      classification_aliases = DataCycleCore::ClassificationAlias.where(external_source_id: external_system_id)
      puts "MIGRATING: classification_aliases (#{classification_aliases.size})..."
      classification_aliases.update_all(external_source_id: nil)

      puts 'MIGRATION SUCCESSFUL'
    end

    desc 'make external_system_sync to primary external_source'
    task :make_external_system_sync_primary, [:stored_filter_id, :external_system_identifier] => :environment do |_, args|
      sf = DataCycleCore::StoredFilter.find(args.stored_filter_id)
      abort('No Stored Filter found!') if sf.blank?

      es = DataCycleCore::ExternalSystem.find_by(identifier: args.external_system_identifier)
      abort('No External System found!') if es.blank?

      iterator = sf.apply
      progressbar = ProgressBar.create(total: iterator.count, format: '%t |%w>%i| %a - %c/%C', title: 'Switching sources...')

      iterator.each do |thing|
        sync = thing.external_system_syncs.find_by(external_system_id: es.id)
        progressbar.increment
        next if sync.blank?
        thing.switch_primary_external_system(sync)
      end

      puts "DONE: #{es.name} is now primary System for all Things provided."
    end

    desc 'download external assets into dataCycle for things with external_system_id'
    task :download_external_assets, [:external_system_id] => :environment do |_, args|
      logger = Logger.new('log/download_assets.log')
      logger.info('Started Downloading...')

      external_system_id = args[:external_system_id]
      allowed_template_names = DataCycleCore::ThingTemplate.where("thing_templates.schema -> 'properties' ->> 'asset' IS NOT NULL").pluck(:template_name)

      if external_system_id.blank? || allowed_template_names.blank?
        error = 'external_system_id not given or no viable Templates found'
        logger.error(error) && abort(error)
      end

      asset_sql = <<-SQL.squish
        NOT EXISTS (
          SELECT 1 FROM assets
          INNER JOIN asset_contents
          ON asset_contents.asset_id = assets.id
          WHERE asset_contents.content_data_id = things.id
        )
      SQL

      contents = DataCycleCore::Thing.by_external_system(external_system_id).where(template_name: allowed_template_names).where(asset_sql)

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'MIGRATING: things')
      logger.info("DOWNLOADING: assets for #{contents.size} things...")

      contents.find_each do |content|
        I18n.with_locale(content.first_available_locale) do
          asset_type = content.schema&.dig('properties', 'asset', 'asset_type')
          logger.warn("missing asset_type for #{content.id}") && next if asset_type.blank?

          file_url = content.try(:content_url)
          logger.warn("missing content_url for #{content.id}") && next if file_url.blank?

          asset = DataCycleCore.asset_objects.find { |a| a == "DataCycleCore::#{asset_type.classify}" }&.safe_constantize&.new(name: content.title, remote_file_url: file_url)

          logger.error("asset for #{content.id} not saved: #{asset.errors&.full_messages}") && next unless asset&.save

          content.external_source_to_external_system_syncs('import')

          valid = content.set_data_hash(
            data_hash: {
              asset: asset.id,
              url: nil
            },
            prevent_history: true,
            update_search_all: false
          )

          if valid
            logger.info("Successfully loaded asset for #{content.id} from #{file_url}")
          else
            logger.error("Error saving content: #{content.errors.messages}")
          end

          progressbar.increment
        end
      end

      logger.info('DOWNLOAD SUCCESSFUL')
    end

    desc 'migrate embedded Öffnungszeit to opening_time'
    task migrate_opening_hours: :environment do
      description_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Öffnungszeit - Beschreibung')

      contents = DataCycleCore::Thing.where(template_name: 'Öffnungszeit')
      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Öffnungszeit')

      contents.find_each do |content|
        next progressbar.increment unless content.embedded?

        thing_relation = content.content_content_b.find_by(relation_a: ['opening_hours_specification', 'dining_hours_specification'])

        next progressbar.increment if thing_relation.nil?

        content.time.find_each do |time_content|
          schedule = DataCycleCore::Schedule.new({
            thing_id: thing_relation.content_a_id,
            relation: thing_relation.relation_a
          })
          duration = DataCycleCore::Schedule.time_to_duration(time_content.opens, time_content.closes)

          if content.validity&.valid_from.nil? && content.validity&.valid_to.nil?
            start_time = "2021-01-01 #{time_content.opens}".in_time_zone
            until_time = '2024-01-01'.in_time_zone
          else
            start_time = "#{content.validity&.valid_from} #{time_content.opens}".in_time_zone
            until_time = content.validity.valid_through&.in_time_zone&.end_of_day || 3.years.from_now.in_time_zone.end_of_day
          end

          schedule.from_hash({
            start_time: {
              time: start_time.to_s,
              zone: start_time.time_zone.name
            },
            duration:,
            rrules: [{
              rule_type: 'IceCube::WeeklyRule',
              validations: {
                day: content.day_of_week&.pluck(:uri)&.map { |d| DataCycleCore::Schedule::DAY_OF_WEEK_MAPPING.key(d) }
              },
              until: until_time
            }]
          }.deep_reject { |_, v| v.blank? && !v.is_a?(FalseClass) }.with_indifferent_access)

          schedule.save!
        end

        content.available_locales.each do |locale|
          I18n.with_locale(locale) do
            next if content.description.blank?

            description_content = DataCycleCore::Thing.new(thing_template: description_template)
            description_content.save!

            from_date = content.validity&.valid_from&.in_time_zone&.beginning_of_day || Time.zone.now.beginning_of_day
            duration = 1.day.to_i

            if content.validity&.valid_through.present?
              duration = content.validity.valid_through.in_time_zone.change({ hour: 23, min: 59, sec: 59 }) - from_date
            else
              rrules = [{
                rule_type: 'IceCube::DailyRule'
              }]
            end

            description_content.set_data_hash(data_hash: {
              description: content.description,
              validity_schedule: [{
                start_time: {
                  time: from_date.to_s,
                  zone: from_date.time_zone.name
                },
                duration:,
                rrules:
              }.with_indifferent_access]
            }, prevent_history: true, new_content: true)

            relation_a = thing_relation.relation_a == 'opening_hours_specification' ? 'opening_hours_description' : 'dining_hours_description'

            DataCycleCore::ContentContent.create!({
              content_a_id: thing_relation.content_a_id,
              relation_a:,
              order_a: thing_relation.order_a,
              content_b_id: description_content.id
            })
          end
        end

        content.destroy_children
        content.destroy
        progressbar.increment
      end
    end

    desc 'migrate event places from Örtlichkeit to POI'
    task ortlichkeit_to_poi: :environment do
      poi_class = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'POI')
      poi_template = DataCycleCore::ThingTemplate.find_by(template_name: 'POI')

      systems = ['feratel']
      systems.each do |identifier|
        es = DataCycleCore::ExternalSystem.find_by(identifier:)
        next if es.blank?
        DataCycleCore::Thing.where(template_name: 'Örtlichkeit', external_source_id: es.id).find_each do |place|
          # update data-type
          DataCycleCore::ClassificationContent.where(content_data_id: place.id, relation: 'data_type').update_all(classification_id: poi_class)
          # update template, template definition
          place.template_name = poi_template.template_name
          place.cache_valid_since = Time.zone.now
          place.save
          # update search table
          place.search_languages(true)
        end
      end
    end

    desc 'migrate uniq external_keys for OutdoorActive additionalInformation'
    task oa_external_key: :environment do
      es = DataCycleCore::ExternalSystem.find_by(identifier: 'outdooractive')
      exit(1) if es.blank?

      contents = DataCycleCore::Thing.where(template_name: 'Ergänzende Information', external_source_id: es.id, external_key: nil).includes(:classifications, :translations)
      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Ergänzende Information')
      contents.each do |item|
        desc = item.classifications.first.name
        locale = item.available_locales.first
        parent_external_key = DataCycleCore::ContentContent.where(content_b_id: item.id).first.content_a.external_key
        item.external_key = "#{desc}:#{locale}:#{parent_external_key}"
        item.save!(touch: false)
        progressbar.increment
      end
    end

    desc 'rebuild schedule_occurrences'
    task rebuild_schedule_occurrences: :environment do
      rebuild_occurrences_sql = <<-SQL
        TRUNCATE schedule_occurrences;

        SELECT
          generate_schedule_occurences (ARRAY_AGG(id))
        FROM
          schedules;
      SQL

      ActiveRecord::Base.connection.execute(rebuild_occurrences_sql)
    end

    desc 'remove multiple BYYEARDAY in schedules'
    task remove_multiple_byyearday: :environment do
      byyearday_sql = <<-SQL
        UPDATE
          schedules
        SET
          rrule = REPLACE(rrule, 'BYYEARDAY=' || array_to_string(get_byyearday (rrule::rrule), ','),
            'BYYEARDAY=' || (get_byyearday (rrule::rrule))[1])
        WHERE
          array_length(get_byyearday (rrule::rrule), 1) > 1;
      SQL

      ActiveRecord::Base.connection.execute(byyearday_sql)
    end

    desc 'migrate watchlists to paths with separator'
    task migrate_watchlists_to_paths: :environment do
      items = DataCycleCore::WatchList.all
      progressbar = ProgressBar.create(total: items.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      items.find_each do |wl|
        wl.send(:split_full_path)
        wl.save!(touch: false)
        progressbar.increment
      end
    end

    task :external_to_univeral_classifications, [:stored_filter] => :environment do |_, args|
      contents = DataCycleCore::Thing.where(id: DataCycleCore::StoredFilter.find(args[:stored_filter]).apply.select(:id))

      ActiveRecord::Base.connection.execute <<-SQL.squish
        INSERT INTO
          classification_contents (
            content_data_id,
            classification_id,
            seen_at,
            created_at,
            updated_at,
            relation
          )
        SELECT
          cc.content_data_id,
          cc.classification_id,
          cc.seen_at,
          cc.created_at,
          cc.updated_at,
          'universal_classifications'
        FROM
          classification_contents cc
          INNER JOIN classifications ON classifications.deleted_at IS NULL
          AND classifications.id = cc.classification_id
        WHERE
          cc.content_data_id IN (#{contents.select(:id).to_sql})
          AND cc.relation != 'universal_classifications'
          AND classifications.external_source_id IS NOT NULL ON CONFLICT
        DO
          NOTHING;

        DELETE FROM
          classification_contents
        WHERE
          classification_contents.id IN (
            SELECT
              classification_contents.id
            FROM
              classification_contents
              INNER JOIN classifications ON classifications.deleted_at IS NULL
              AND classifications.id = classification_contents.classification_id
            WHERE
              classification_contents.content_data_id IN (#{contents.select(:id).to_sql})
              AND classification_contents.relation != 'universal_classifications'
              AND classifications.external_source_id IS NOT NULL
          );
      SQL
    end

    task :universal_to_attribute_classifications, [:stored_filter_id, :tree_name, :attribute_key] => :environment do |_, args|
      abort('missing stored_filter_id') if args.stored_filter_id.blank?
      abort('missing attribute_key') if args.attribute_key.blank?

      tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: args.tree_name)

      abort('missing tree_label') if tree_label.nil?

      contents = DataCycleCore::StoredFilter.find(args.stored_filter_id).apply.query

      query = DataCycleCore::ClassificationContent
        .joins(classification: [primary_classification_alias: :classification_tree_label])
        .where(
          content_data_id: contents.select(:id),
          relation: 'universal_classifications',
          classifications: { primary_classification_aliases: { classification_tree_labels: { id: tree_label.id } } }
        )

      raw_query = <<-SQL.squish
        UPDATE
          classification_contents
        SET
          relation = :relation
        WHERE
          classification_contents.id IN (#{query.select(:id).to_sql})
          AND NOT EXISTS (
            SELECT
              1
            FROM
              classification_contents c1
            WHERE
              classification_contents.content_data_id = c1.content_data_id
              AND classification_contents.classification_id = c1.classification_id
              AND c1.relation = :relation
          );
      SQL

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_for_conditions, [raw_query, relation: args.attribute_key])
      )

      query.delete_all
    end

    task :pull_classifications_from_embedded, [:stored_filter, :embedded, :source_relation, :target_relation] => :environment do |_, args|
      contents = DataCycleCore::Thing.where(id: DataCycleCore::StoredFilter.find(args[:stored_filter]).apply.select(:id))

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'MIGRATING')

      contents.each do |thing|
        embedded_contents = DataCycleCore::ContentContent.where(content_a: thing.id, relation_a: args[:embedded])

        DataCycleCore::ClassificationContent
          .where(content_data_id: embedded_contents.select(:content_b_id), relation: args[:source_relation])
          .update_all(content_data_id: thing.id, relation: args[:target_relation])

        progressbar.increment
      end
    end

    task :tours, [:stored_filter] => :environment do |_, args|
      contents = DataCycleCore::Thing.where(template_name: 'Tour')

      contents = contents.where(id: DataCycleCore::StoredFilter.find(args[:stored_filter]).apply.select(:id)) if args[:stored_filter]

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'MIGRATING')

      contents.includes(:translations).find_each do |content|
        translation = content.translations.first

        if translation&.content&.dig('author')
          author = I18n.with_locale(translation.locale) do
            ContentHelper.find_or_create_content(
              external_source: content.external_source,
              external_key: Digest::MD5.hexdigest(translation.content['author']),
              template_name: 'Organization',
              data: { name: translation.content['author'] }
            )
          end
        end

        publishers = content.classifications_for_tree(tree_name: 'OutdoorActive - Quellen').map do |classification|
          ContentHelper.find_or_create_content(
            external_source: content.external_source,
            external_key: Digest::MD5.hexdigest(classification.name),
            template_name: 'Organization',
            data: { name: classification.name }
          )
        end

        data = {
          author: author ? [author.id] : [],
          sd_publisher: publishers.map(&:id),
          image: (content.primary_image.map(&:id) + content.image.map(&:id)).uniq,
          primary_image: [],
          aggregate_rating: content.metadata.select { |k, _|
                              k =~ /_rating$/
                            }.select { |_, v|
                              v.to_i.positive?
                            }.map do |k, v|
                              {
                                'id' => DataCycleCore::Thing.where(
                                  external_source_id: content.external_source_id,
                                  external_key: [content.external_key, k].join(' - ')
                                ).pick(:id),
                                'external_key' => [content.external_key, k].join(' - '),
                                'name' => I18n.t('import.outdoor_active.ratings.' + k, default: k),
                                'rating_value' => v.to_i,
                                'worst_rating' => 1,
                                'best_rating' => k == 'difficulty_rating' ? 3 : 6
                              }
                            end
        }

        unless content.set_data_hash(data_hash: data)
          puts "Cannot migrate ##{content.id}:"
          puts content.errors.full_messages.map { |m| "  #{m}" }.join("\n")
          puts
        end

        DataCycleCore::ContentContent.where(content_a: content.id, relation_a: 'poi').update_all(relation_a: 'waypoint')

        content.additional_information.select { |c| c.name == I18n.t('import.outdoor_active.tour.description') }.each(&:destroy!)

        DataCycleCore::ContentContent.where(content_a: content.id, relation_a: 'aggregate_rating').map(&:content_b).each do |rating|
          rating_key = [
            'technique_rating', 'condition_rating', 'experience_rating', 'landscape_rating', 'difficulty_rating'
          ].find { |k| rating.name == I18n.t('import.outdoor_active.ratings.' + k, default: k) }

          next unless rating_key

          content.translations.map(&:locale).each do |locale|
            I18n.with_locale(locale) do
              rating.set_data_hash(data_hash: {
                'name' => I18n.t('import.outdoor_active.ratings.' + rating_key, default: rating_key)
              })
            end
          end
        end

        progressbar.increment
      end
    end

    desc 'download external assets into dataCycle for things with external_system_id'
    task outdoor_active_oertlichkeit_to_feratel_poi: :environment do
      outdoor_active = DataCycleCore::ExternalSystem.find_by(identifier: 'outdooractive')
      abort('outdooractive external system not found!') if outdoor_active.nil?
      feratel = DataCycleCore::ExternalSystem.find_by(identifier: 'feratel')
      abort('feratel external system not found!') if feratel.nil?

      aggregation = [
        { '$match': { 'dump.de.meta.externalSystem.name': { '$exists': true } } },
        { '$match': { 'dump.de.meta.externalId.id': { '$exists': true } } },
        { '$match': { 'dump.de.meta.externalSystem.name': /.*feratel.*/i } },
        { '$match': { 'dump.de.frontendtype': 'poi' } },
        { '$project': { 'external_id': '$dump.de.id', 'external_key': '$dump.de.meta.externalId.id' } }
      ]

      places = outdoor_active.query('places') { |i| i.collection.aggregate(aggregation).to_a }.to_h { |p| [p['external_id'], p['external_key']] }
      contents = DataCycleCore::Thing.where(external_source_id: outdoor_active.id, template_name: 'Örtlichkeit', external_key: places.keys)
      existing_feratel = DataCycleCore::Thing.where(external_source_id: feratel.id, external_key: places.values).pluck(:external_key, :id).to_h

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      contents.find_each do |content|
        feratel_thing_id = existing_feratel[places[content.external_key]]

        next progressbar.increment if feratel_thing_id.nil?

        begin
          content.content_content_b.update_all(content_b_id: feratel_thing_id)
        rescue ActiveRecord::RecordNotUnique
          nil
        end

        begin
          DataCycleCore::ExternalSystemSync.find_or_create_by(syncable_id: feratel_thing_id, syncable_type: 'DataCycleCore::Thing', sync_type: 'duplicate', external_system_id: outdoor_active.id, external_key: content.external_key) do |sync|
            sync.status = 'success'
            sync.data = { 'external_key' => content.external_key }
            sync.last_sync_at = content.updated_at
            sync.last_successful_sync_at = content.updated_at
          end
        rescue ActiveRecord::RecordNotUnique
          nil
        end

        content.destroy_content

        progressbar.increment
      end
    end

    desc 'migrate potential_action string to embedded'
    task potential_action_string_to_embedded: :environment do
      # migrate Pimcore Events
      external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'pimcore')
      if external_source.present?
        contents = DataCycleCore::Thing.includes(:external_source).where(template_name: 'Event', external_source_id: external_source.id).where("EXISTS(SELECT 1 FROM thing_translations WHERE thing_translations.thing_id = things.id AND thing_translations.content ->> 'potential_action' IS NOT NULL AND thing_translations.content ->> 'potential_action' != '')")
        action_type = DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('ActionTypes', 'View')
        progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

        contents.find_each do |content|
          I18n.with_locale(content.first_available_locale) do
            data_hash = {
              'potential_action' => content.attribute_to_h('potential_action')
            }
            new_action = {
              datahash: {
                'external_key' => "#{content.external_key} - #{content.content&.dig('potential_action')}",
                'external_source_id' => external_source.id,
                'action_type' => action_type
              },
              translations: {}
            }

            content.translated_locales.each do |locale|
              I18n.with_locale(locale) do
                next if content.content&.dig('potential_action').blank?

                new_action[:translations][locale] ||= {}
                new_action[:translations][locale]['name'] = 'potential_action'
                new_action[:translations][locale]['url'] = content.content&.dig('potential_action')

                DataCycleCore::Thing::Translation.find_by(locale: I18n.locale, thing_id: content.id).update_columns(content: content.content&.except('potential_action'))
              end
            end

            data_hash['potential_action'] << new_action if new_action[:translations].present?

            content.set_data_hash_with_translations(data_hash:, prevent_history: true)
          rescue StandardError => e
            puts e.message
          ensure
            progressbar.increment
          end
        end
      end

      contents = DataCycleCore::Thing.where(template_name: ['Event', 'Eventserie']).where("EXISTS(SELECT 1 FROM thing_translations WHERE thing_translations.thing_id = things.id AND thing_translations.content ->> 'potential_action' IS NOT NULL AND thing_translations.content ->> 'potential_action' != '')")
      action_type = DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('ActionTypes', 'View')
      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      contents.find_each do |content|
        I18n.with_locale(content.first_available_locale) do
          data_hash = {
            'potential_action' => content.reload.attribute_to_h('potential_action')
          }
          new_action = {
            datahash: {
              'action_type' => action_type
            },
            translations: {}
          }

          content.translated_locales.each do |locale|
            I18n.with_locale(locale) do
              next if content.content&.dig('potential_action').blank?

              new_action[:translations][locale] ||= {}
              new_action[:translations][locale]['name'] = 'potential_action'
              new_action[:translations][locale]['url'] = content.content&.dig('potential_action')

              DataCycleCore::Thing::Translation.find_by(locale: I18n.locale, thing_id: content.id).update_columns(content: content.content&.except('potential_action'))
            end
          end

          data_hash['potential_action'] << new_action if new_action[:translations].present?
          content.set_data_hash_with_translations(data_hash:, prevent_history: true)
        rescue StandardError => e
          puts e.message
        ensure
          progressbar.increment
        end
      end
    end

    desc 'migrate description and text string to additional_information'
    task :strings_to_additional_information, [:template_names] => :environment do |_, args|
      template_names = args.template_names&.split('|')
      count = 0

      template_names.each do |template_name|
        contents = DataCycleCore::Thing.where(template_name:, external_source_id: nil)
        progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: template_name)

        contents.find_each do |content|
          content.translated_locales.each do |locale|
            I18n.with_locale(locale) do
              next if content.try('description').blank? && content.try('text').blank?

              additional_information = content.to_h_partial('additional_information')&.[]('additional_information') || []
              new_informations = []

              ['description', 'text'].each do |key|
                value = content.try(key)
                next if value.blank?
                next if additional_information.any? { |v| DataCycleCore::MasterData::DataConverter.string_to_string(v['description']&.strip_tags) == DataCycleCore::MasterData::DataConverter.string_to_string(value&.strip_tags) }

                new_informations.push({
                  'name' => I18n.t("import.pimcore.#{key}", locale: locale.to_s.in?(['de', 'en']) ? locale : 'de'),
                  'description' => value,
                  'type_of_information' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Informationstypen', key)
                })
              end

              next if new_informations.blank?

              additional_information.each { |a| a.slice!('id') }
              additional_information.concat(new_informations)

              content.set_data_hash(data_hash: { additional_information: })

              count += 1
            end
          end

          progressbar.increment
        end
      end

      puts "updated #{count} things"
    end
  end
end
