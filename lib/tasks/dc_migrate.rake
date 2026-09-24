# frozen_string_literal: true

require 'rake_helpers/content_helper'

namespace :dc do
  namespace :migrate do
    desc 'move external_source_id and external_key from things to external_system_syncs (also downloads external assets unless skip_asset_download is true)'
    task :external_source_to_system, [:external_system_or_stored_filter_id, :skip_asset_download] => :environment do |_, args|
      external_system_or_stored_filter_id = args.external_system_or_stored_filter_id
      skip_asset_download = args.skip_asset_download.to_s == 'true'

      abort('ExternalSystem- or StoredFilter-Id missing!') if external_system_or_stored_filter_id.blank?

      stored_filter = DataCycleCore::Collection.by_id_name_slug(external_system_or_stored_filter_id).first
      external_system = DataCycleCore::ExternalSystem.find_by(id: external_system_or_stored_filter_id)

      abort('ExternalSystem or StoredFilter not found!') if stored_filter.nil? && external_system.nil?

      stored_filter = DataCycleCore::StoredFilter.new if stored_filter.nil?
      query = stored_filter.things
      query = query.where(external_source_id: external_system.id) if external_system.present?

      raw_sql = <<~SQL.squish
        WITH RECURSIVE
          content_dependencies AS (
            SELECT
              t.id
            FROM
              things AS t
            WHERE
              t.id IN (#{query.except(:order).select(:id).to_sql})
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
      progressbar1 = ProgressBar.create(total: embeddeds.size, title: 'MIGRATING: embeddeds')

      embeddeds.each do |embedded|
        embedded.external_source_to_external_system_syncs(DataCycleCore::ExternalSystemSync::SYNC_TYPES[:duplicate])

        progressbar1.increment
      end

      contents = query.except(:order)

      schedules = DataCycleCore::Schedule.where(thing_id: contents.select(:id))
      puts "MIGRATING: schedules (#{schedules.size})..."
      schedules.update_all(external_source_id: nil, external_key: nil)

      progressbar = ProgressBar.create(total: contents.size, title: 'MIGRATING: things')

      contents.each do |content|
        content.external_source_to_external_system_syncs(DataCycleCore::ExternalSystemSync::SYNC_TYPES[:duplicate])

        progressbar.increment
      end

      puts 'MIGRATION SUCCESSFUL'

      unless skip_asset_download
        puts 'DOWNLOADING EXTERNAL ASSETS...'
        Rake::Task['dc:migrate:download_external_assets'].invoke(external_system&.id, stored_filter&.id)
        Rake::Task['dc:migrate:download_external_assets'].reenable
      end
    end

    desc 'remove external_source_id and external_key from things to external_system_syncs'
    task :remove_external_source_from_classifications, [:external_system_id] => :environment do |_, args|
      external_system_id = args.external_system_id

      abort('ExternalSystemId missing!') if external_system_id.blank?

      concepts = DataCycleCore::Concept.where(external_system_id:)
      puts "MIGRATING: concepts (#{concepts.size})..."
      concepts.update_all(external_system_id: nil, external_key: nil)

      concept_schemes = DataCycleCore::ConceptScheme.where(external_system_id:)
      puts "MIGRATING: concept_schemes (#{concept_schemes.size})..."
      concept_schemes.update_all(external_system_id: nil)

      puts 'MIGRATION SUCCESSFUL'
    end

    desc 'make external_system_sync to primary external_source'
    task :make_external_system_sync_primary, [:stored_filter_id, :external_system_identifier] => :environment do |_, args|
      sf = DataCycleCore::Collection.by_id_name_slug(args.stored_filter_id).first
      abort('No Stored Filter found!') if sf.nil?

      es = DataCycleCore::ExternalSystem.by_names_identifiers_or_ids(args.external_system_identifier).first
      abort('No External System found!') if es.nil?

      iterator = sf.things
      queue = DataCycleCore::WorkerPool.new
      progressbar = ProgressBar.create(total: iterator.size, title: 'Switching sources...')

      iterator.find_each do |thing|
        queue.append do
          sync = thing.external_system_syncs.find_by(external_system_id: es.id)
          next(progressbar.increment) if sync.blank?

          thing.switch_primary_external_system(sync)
          progressbar.increment
        end
      end

      queue.wait!

      puts "DONE: #{es.name} is now primary System for all Things provided."
    end

    desc 'download external assets into dataCycle for things with external_system_id or collection_id'
    task :download_external_assets, [:external_system_id, :collection_id] => :environment do |_, args|
      collection_id = args.collection_id
      external_system_id = args.external_system_id

      logger = Logger.new('log/download_assets.log')
      logger.info('Started Downloading...')
      if external_system_id.blank? && collection_id.blank?
        error = 'external_system_id or collection_id not given'
        logger.error(error) && abort(error)
      end
      collection = DataCycleCore::Collection.find_by(id: collection_id)
      if collection_id.present? && collection.blank?
        error = "collection with id #{collection_id} not found"
        logger.error(error) && abort(error)
      end

      allowed_template_names = DataCycleCore::ThingTemplate.where("thing_templates.schema -> 'properties' ->> 'asset' IS NOT NULL").pluck(:template_name)

      if allowed_template_names.blank?
        error = 'no viable Templates found'
        logger.error(error) && abort(error)
      end

      es = DataCycleCore::ExternalSystem.find_by(id: external_system_id)
      if external_system_id.present? && es.blank?
        error = "external_system with id #{external_system_id} not found"
        logger.error(error) && abort(error)
      end

      asset_sql = <<~SQL.squish
        NOT EXISTS (
          SELECT 1 FROM assets
          INNER JOIN asset_contents
          ON asset_contents.asset_id = assets.id
          WHERE asset_contents.thing_id = things.id
        )
      SQL

      contents = nil

      if collection_id.present? && external_system_id.present?
        contents = DataCycleCore::Thing.where(id: DataCycleCore::Collection.find(collection_id).apply.select(:id)).by_external_system(external_system_id).where(template_name: allowed_template_names).where(asset_sql)
      elsif collection_id.present?
        contents = DataCycleCore::Thing.where(id: DataCycleCore::Collection.find(collection_id).things.select(:id)).where(template_name: allowed_template_names).where(asset_sql)
      elsif external_system_id.present?
        contents = DataCycleCore::Thing.by_external_system(external_system_id).where(template_name: allowed_template_names).where(asset_sql)
      end

      progressbar = ProgressBar.create(total: contents.size, title: 'MIGRATING: things')
      logger.info("DOWNLOADING: assets for #{contents.size} things...")
      queue = DataCycleCore::WorkerPool.new

      contents.find_each do |content|
        queue.append do
          I18n.with_locale(content.first_available_locale) do
            asset_type = content.schema&.dig('properties', 'asset', 'asset_type')
            if asset_type.blank?
              logger.warn("missing asset_type for #{content.id}")
              progressbar.increment
              next
            end

            file_url = content.try(:content_url)
            if file_url.blank?
              logger.warn("missing content_url for #{content.id}")
              progressbar.increment
              next
              # elsif file_url.split('/').last&.starts_with?('.')
              #   # add dummy filename if missing
              #   file_url = file_url.split('/').tap { |a| a[-1] = "dummy.#{file_url.split('.').last}" }.join('/')
            end

            asset_model = DataCycleCore.asset_objects
              .find { |a| a == "DataCycleCore::#{asset_type.classify}" }
              &.safe_constantize
            asset = asset_model&.new(name: content.title, remote_file_url: file_url)

            unless asset&.save
              logger.error("asset for #{content.id} not saved: #{asset.errors&.full_messages}")
              progressbar.increment
              next
            end

            content.external_source_to_external_system_syncs(DataCycleCore::ExternalSystemSync::SYNC_TYPES[:duplicate])

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
          rescue DataCycleCore::Error::Asset::RemoteFileDownloadError
            progressbar.increment
            logger.error("Error downloading asset for #{content.id} from #{file_url}")
          end
        end
      end

      queue.wait!

      logger.info('DOWNLOAD SUCCESSFUL')
    end

    desc 'migrate embedded Öffnungszeit to opening_time'
    task migrate_opening_hours: :environment do
      description_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Öffnungszeit - Beschreibung')

      contents = DataCycleCore::Thing.where(template_name: 'Öffnungszeit')
      progressbar = ProgressBar.create(total: contents.size, title: 'Öffnungszeit')

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
      poi_class = DataCycleCore::Concept.id_for_tree_with_name('Inhaltstypen', 'POI')
      poi_template = DataCycleCore::ThingTemplate.find_by(template_name: 'POI')

      systems = ['feratel']
      systems.each do |identifier|
        es = DataCycleCore::ExternalSystem.find_by(identifier:)
        next if es.blank?

        DataCycleCore::Thing.where(template_name: 'Örtlichkeit', external_source_id: es.id).find_each do |place|
          # update data-type
          DataCycleCore::ConceptContent.where(content_data_id: place.id, relation: 'data_type').update_all(concept_id: poi_class)
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

      contents = DataCycleCore::Thing.where(template_name: 'Ergänzende Information', external_source_id: es.id, external_key: nil).includes(:concepts, :translations)
      progressbar = ProgressBar.create(total: contents.size, title: 'Ergänzende Information')
      contents.each do |item|
        desc = item.concepts.first.name
        locale = item.available_locales.first
        parent_external_key = DataCycleCore::ContentContent.where(content_b_id: item.id).first.content_a.external_key
        item.external_key = "#{desc}:#{locale}:#{parent_external_key}"
        item.save!(touch: false)
        progressbar.increment
      end
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
      progressbar = ProgressBar.create(total: items.size, title: 'Progress')

      items.find_each do |wl|
        wl.send(:split_full_path)
        wl.save!(touch: false)
        progressbar.increment
      end
    end

    desc 'migrate external classifications to universal classifications'
    task :external_to_universal_classifications, [:stored_filter] => :environment do |_, args|
      contents = DataCycleCore::Thing.where(id: DataCycleCore::StoredFilter.find(args[:stored_filter]).apply.select(:id))

      ActiveRecord::Base.connection.execute <<~SQL.squish
        INSERT INTO
          concept_contents (
            content_data_id,
            concept_id,
            seen_at,
            created_at,
            updated_at,
            relation
          )
        SELECT
          cc.content_data_id,
          cc.concept_id,
          cc.seen_at,
          cc.created_at,
          cc.updated_at,
          'universal_classifications'
        FROM
          concept_contents cc
          INNER JOIN concepts ON concepts.id = cc.concept_id
        WHERE
          cc.content_data_id IN (#{contents.select(:id).to_sql})
          AND cc.relation != 'universal_classifications'
          AND concepts.external_system_id IS NOT NULL ON CONFLICT
        DO
          NOTHING;

        DELETE FROM
          concept_contents
        WHERE
          concept_contents.id IN (
            SELECT
              concept_contents.id
            FROM
              concept_contents
              INNER JOIN concepts ON concepts.id = concept_contents.concept_id
            WHERE
              concept_contents.content_data_id IN (#{contents.select(:id).to_sql})
              AND concept_contents.relation != 'universal_classifications'
              AND concepts.external_system_id IS NOT NULL
          );
      SQL
    end

    desc 'migrate universal classifications to attribute classifications'
    task :universal_to_attribute_classifications, [:stored_filter_id, :tree_name, :attribute_key] => :environment do |_, args|
      abort('missing stored_filter_id') if args.stored_filter_id.blank?
      abort('missing attribute_key') if args.attribute_key.blank?

      tree_label = DataCycleCore::ConceptScheme.find_by(name: args.tree_name)

      abort('missing tree_label') if tree_label.nil?

      contents = DataCycleCore::StoredFilter.find(args.stored_filter_id).apply.query

      query = DataCycleCore::ConceptContent
        .joins(:concept)
        .where(
          content_data_id: contents.select(:id),
          relation: 'universal_classifications',
          concepts: { concept_scheme_id: tree_label.id }
        )

      raw_query = <<~SQL.squish
        UPDATE
          concept_contents
        SET
          relation = :relation
        WHERE
          concept_contents.id IN (#{query.select(:id).to_sql})
          AND NOT EXISTS (
            SELECT
              1
            FROM
              concept_contents c1
            WHERE
              concept_contents.content_data_id = c1.content_data_id
              AND concept_contents.concept_id = c1.concept_id
              AND c1.relation = :relation
          );
      SQL

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_for_conditions, [raw_query, { relation: args.attribute_key }])
      )

      query.delete_all
    end

    desc 'migrate classifications from embedded to content things'
    task :pull_classifications_from_embedded, [:stored_filter, :embedded, :source_relation, :target_relation] => :environment do |_, args|
      contents = DataCycleCore::Thing.where(id: DataCycleCore::StoredFilter.find(args[:stored_filter]).apply.select(:id))

      progressbar = ProgressBar.create(total: contents.size, title: 'MIGRATING')

      contents.each do |thing|
        embedded_contents = DataCycleCore::ContentContent.where(content_a: thing.id, relation_a: args[:embedded])

        DataCycleCore::ConceptContent
          .where(content_data_id: embedded_contents.select(:content_b_id), relation: args[:source_relation])
          .update_all(content_data_id: thing.id, relation: args[:target_relation])

        progressbar.increment
      end
    end

    desc 'migrate tours'
    task :tours, [:stored_filter] => :environment do |_, args|
      contents = DataCycleCore::Thing.where(template_name: 'Tour')

      contents = contents.where(id: DataCycleCore::StoredFilter.find(args[:stored_filter]).apply.select(:id)) if args[:stored_filter]

      progressbar = ProgressBar.create(total: contents.size, title: 'MIGRATING')

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

        publishers = content.concepts_for_tree(scheme_name: 'OutdoorActive - Quellen').map do |concept|
          ContentHelper.find_or_create_content(
            external_source: content.external_source,
            external_key: Digest::MD5.hexdigest(concept.name),
            template_name: 'Organization',
            data: { name: concept.name }
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
                                'name' => I18n.t("import.outdoor_active.ratings.#{k}", default: k),
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
          ].find { |k| rating.name == I18n.t("import.outdoor_active.ratings.#{k}", default: k) }

          next unless rating_key

          content.translations.map(&:locale).each do |locale|
            I18n.with_locale(locale) do
              rating.set_data_hash(data_hash: {
                'name' => I18n.t("import.outdoor_active.ratings.#{rating_key}", default: rating_key)
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
        { '$project': { external_id: '$dump.de.id', external_key: '$dump.de.meta.externalId.id' } }
      ]

      places = outdoor_active.query('places') { |i| i.collection.aggregate(aggregation).to_a }.to_h { |p| [p['external_id'], p['external_key']] }
      contents = DataCycleCore::Thing.where(external_source_id: outdoor_active.id, template_name: 'Örtlichkeit', external_key: places.keys)
      existing_feratel = DataCycleCore::Thing.where(external_source_id: feratel.id, external_key: places.values).pluck(:external_key, :id).to_h

      progressbar = ProgressBar.create(total: contents.size, title: 'Progress')

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
        action_type = DataCycleCore::Concept.ids_for_tree_with_name('ActionTypes', 'View')
        progressbar = ProgressBar.create(total: contents.size, title: 'Progress')

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
      action_type = DataCycleCore::Concept.ids_for_tree_with_name('ActionTypes', 'View')
      progressbar = ProgressBar.create(total: contents.size, title: 'Progress')

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
        progressbar = ProgressBar.create(total: contents.size, title: template_name)

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
                  'type_of_information' => DataCycleCore::Concept.ids_for_tree_with_name('Informationstypen', key)
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

    desc 'create missing translations for aggregates'
    task create_missing_translations_for_aggregates: :environment do
      things = DataCycleCore::Thing.where(aggregate_type: 'belongs_to_aggregate')
      things = things.where('exists(select 1 from thing_translations tt where tt.thing_id = things.id and tt.locale != ?)', 'de')

      puts "Processing #{things.count} things"

      things.find_each do |thing|
        aggregate = thing.belongs_to_aggregate.first

        next print('~') if aggregate.nil?
        next print('~') unless aggregate.translatable?

        aggregate_for = aggregate.aggregate_for.map(&:id)
        missing_locales = aggregate.aggregate_for.flat_map(&:translated_locales).uniq - aggregate.translated_locales

        next print('~') if missing_locales.blank?

        missing_locales.each do |locale|
          I18n.with_locale(locale) do
            valid = aggregate.set_data_hash(data_hash: { aggregate_for: })
            valid ? print('.') : print('x')
          end
        end
      end

      puts "\nProcessed things"
    end

    desc 'overlays to overlay attributes'
    task overlays_to_overlay_attributes: :environment do
      overlays = DataCycleCore::ContentContent.where(relation_a: 'overlay')
      puts('No overlays found!') if overlays.blank?

      progressbar = ProgressBar.create(total: overlays.size, title: 'Progress')

      overlays.preload(:content_a, :content_b).find_each do |overlay|
        content = overlay.content_a
        overlay_content = overlay.content_b
        remove_overlay = true

        overlay_content.available_locales.each do |locale|
          I18n.with_locale(locale) do
            hash = overlay_content.to_h
            to_write = {}
            props = (overlay_content.writable_property_names - overlay_content.computed_property_names - ['id', 'external_key', 'external_source_id'])

            props.each do |pn|
              next if DataCycleCore::DataHashService.blank?(hash[pn])

              override_key = "#{pn}_override"
              add_key = "#{pn}_add"

              if content.property_names.include?(override_key)
                to_write[override_key] = hash[pn]
              elsif content.property_names.include?(add_key)
                to_write[add_key] = hash[pn]
              else
                remove_overlay = false
                puts("#{overlay_content.template_name} (#{pn}) -> #{content.template_name} (#{override_key}) override attribute does not exist!")
              end
            end

            content.set_data_hash(data_hash: to_write, prevent_history: true)
          end
        end

        overlay_content.destroy if remove_overlay

        progressbar.increment
      end

      puts 'MIGRATION SUCCESSFUL'
    end

    desc 'Redmine #39891: retroactively collapse historical timeseries rows for properties with collapse_redundant_values: true (dry_run: true|false)'
    task :collapse_redundant_timeseries_values, [:dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false).to_s == 'true'
      puts '###### DRY-RUN: no database changes will be made' if dry_run

      property_names = DataCycleCore::ContentProperties
        .where("property_definition ->> 'collapse_redundant_values' = 'true'")
        .distinct
        .pluck(:property_name)

      if property_names.blank?
        puts 'no properties with collapse_redundant_values found'
        next
      end

      puts "found #{property_names.size} propert(y/ies): #{property_names.join(', ')}"

      pairs = DataCycleCore::Timeseries.where(property: property_names).select(:thing_id, :property).distinct
      total = pairs.count
      puts "#{total} thing_id/property pair(s) to check"

      progressbar = ProgressBar.create(total:, title: 'Checking')
      collapsed_pairs = 0
      deleted_rows = 0

      pairs.find_in_batches(batch_size: 500) do |batch|
        batch.each do |pair|
          content = DataCycleCore::Thing.find_by(id: pair.thing_id)

          # re-check per content: the flag lives on the template, not the row
          if content&.properties_for(pair.property)&.dig('collapse_redundant_values')
            result = DataCycleCore::Timeseries::RedundantValueCollapser.backfill!(thing_id: pair.thing_id, property: pair.property, dry_run:)

            if result[:deleted].positive?
              collapsed_pairs += 1
              deleted_rows += result[:deleted]
            end
          end

          progressbar.increment
        end
      end

      puts "done: #{collapsed_pairs} pair(s) had redundant rows, #{deleted_rows} row(s) #{dry_run ? 'would be' : 'were'} deleted"
    end

    desc 'Redmine #50874: migrate the legacy text attribute into a leading ContentBlock (dry_run: true|false)'
    task :text_to_content_block, [:template_names, :dry_run] => [:environment] do |_, args|
      template_names = args.template_names.to_s.split('|').map(&:strip).compact_blank
      dry_run = args.dry_run.to_s == 'true'

      abort('ERROR: no template_names given (separate multiple names with "|")') if template_names.blank?
      abort('ERROR: template ContentBlock not found') if DataCycleCore::ThingTemplate.find_by(template_name: 'ContentBlock').nil?

      puts '###### DRY-RUN: no database changes will be made' if dry_run

      # text is a virtual property since #50874 (datacycle-schema-vcloud, structured_article.yml):
      # content.text derives its value from the content blocks and returns nothing for a content
      # that has not been migrated yet, while set_data_hash skips virtual keys instead of writing
      # them. Both the read here and the clearing below therefore go through the translation rows,
      # where the legacy value sits under content -> 'text'. An instance whose template still stores
      # text is read the same way.
      legacy_texts = lambda do |content|
        DataCycleCore::Thing::Translation
          .where(thing_id: content.id)
          .pluck(:locale, :content)
          .to_h { |locale, values| [locale.to_sym, values&.dig('text')] }
          .compact_blank
          .select { |_locale, text| ContentHelper.comparable_text(text).present? } # a text that is only markup carries nothing to move
      end

      # asked three times - which block to fill, which locales still need one, and which legacy
      # values may be dropped - and the three must not drift apart, or a translation gets deleted
      # without a replacement. content.content_block is read through Thing's locale scope, so this
      # only ever sees the blocks that exist in the current locale
      matching_block = lambda do |content, text|
        comparable_text = ContentHelper.comparable_text(text)

        content.content_block.find { |block| ContentHelper.comparable_text(block.try(:text)) == comparable_text }
      end

      template_names.each do |template_name|
        thing_template = DataCycleCore::ThingTemplate.find_by(template_name:)

        next puts("SKIPPED: template #{template_name} not found") if thing_template.nil?
        next puts("SKIPPED: template #{template_name} has no text or content_block") unless ['text', 'content_block'].all? { |key| thing_template.property_names.include?(key) }

        # the predicate belongs in SQL: without it every content of the template is loaded and its
        # translations plucked only to find that there is no legacy text, and skipped then means
        # "nothing to do" rather than "had a text that is already in a block"
        contents = DataCycleCore::Thing.where(template_name:).where("EXISTS(SELECT 1 FROM thing_translations WHERE thing_translations.thing_id = things.id AND thing_translations.content ->> 'text' IS NOT NULL AND thing_translations.content ->> 'text' != '')")
        progress_bar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: template_name)
        migrated = 0
        skipped = 0
        failed = 0

        contents.find_each do |content|
          texts = legacy_texts.call(content)

          next(skipped += 1) if texts.blank?

          primary_locale = texts.key?(content.first_available_locale) ? content.first_available_locale : texts.keys.first

          # a rerun after a dc-sync import must not append the same text a second time
          target_block = I18n.with_locale(primary_locale) { matching_block.call(content, texts[primary_locale]) }

          next(migrated += 1) if dry_run

          # one transaction per content, because the parent's set_data_hash has already committed the
          # new block and its link by the time a later write can fail: without it a failed content
          # keeps an empty block in front of its real ones, and leaks another on every rerun.
          # The rescue below still isolates the contents from each other.
          ActiveRecord::Base.transaction do
            if target_block.nil?
              target_block = I18n.with_locale(primary_locale) do
                known_block_ids = content.content_block.map(&:id)

                # the siblings are passed by id alone: set_embedded re-saves any item carrying a key
                # besides the id, which would re-validate a block's template against the current
                # allow-list and let a legacy template abort the whole content. Their order still
                # follows the array, that branch runs either way
                blocks = content.content_block.map { |block| { 'id' => block.id } }

                # the legacy text goes first because the virtual text returns the first block that
                # carries one - that is what keeps the API emitting the same value as before
                blocks.unshift({ 'template_name' => 'ContentBlock', 'text' => texts[primary_locale] })

                raise "error saving content_block: #{content.errors.messages.to_json}" unless content.set_data_hash(data_hash: { 'content_block' => blocks })

                content.reload.content_block.find { |block| known_block_ids.exclude?(block.id) }
              end

              raise 'error saving content_block: new block not found' if target_block.nil?
            end

            # the remaining translations go onto that same block, never into one of their own:
            # content_block is read through Thing's locale scope, so a block written under a second
            # locale is invisible under the first and the two drift apart as unrelated blocks
            (texts.keys - [primary_locale]).each do |locale|
              I18n.with_locale(locale) do
                next if matching_block.call(content, texts[locale])

                raise "error saving content_block (#{locale}): #{target_block.errors.messages.to_json}" unless target_block.set_data_hash(data_hash: { 'text' => texts[locale] })
              end
            end

            # only once the text is safely stored in a block, drop the legacy attribute - asked per
            # locale, so a translation whose text never reached a block is left alone instead of
            # being dropped with nothing taking its place. The key is removed rather than set to
            # null so a template that stores text again starts empty
            content.reload
            stored_in_block = texts.keys.select { |locale| I18n.with_locale(locale) { matching_block.call(content, texts[locale]).present? } }

            DataCycleCore::Thing::Translation
              .where(thing_id: content.id, locale: stored_in_block)
              .update_all("content = content - 'text'")
          end

          migrated += 1
        rescue StandardError => e
          failed += 1
          progress_bar.log("ERROR: #{template_name} #{content.id} - #{e.message}") # prints above the bar instead of into it
        ensure
          progress_bar.increment
        end

        progress_bar.finish

        puts "done: #{migrated} #{template_name}(s) #{dry_run ? 'would be' : 'were'} migrated, #{skipped} skipped, #{failed} failed"
      end
    end
  end
end
