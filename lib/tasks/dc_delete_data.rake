# frozen_string_literal: true

require 'fastimage'

namespace :dc do
  namespace :delete_data do
    desc 'delete all unreachable asset contents from collection'
    task :unreachable, [:template_name_or_collection_id, :delete_in_use] => [:environment] do |_, args|
      identifier = args.template_name_or_collection_id
      delete_in_use = args.delete_in_use.to_s == 'true'

      abort('Please provide a template name or collection id') if identifier.blank?

      if DataCycleCore::ThingTemplate.exists?(template_name: identifier)
        to_check = DataCycleCore::Thing.where(template_name: identifier)
      else
        collection = DataCycleCore::Collection.by_id_or_slug(identifier).first
        abort("Collection with id or slug '#{identifier}' not found") if collection.nil?
        to_check = collection.things
      end

      template_names_with_assets = DataCycleCore::ContentProperties.where("property_definition ->> 'type' IN (?)", DataCycleCore::Content::Content::ASSET_PROPERTY_TYPES).pluck(:template_name).uniq

      to_check = to_check.where.not(content_type: 'embedded')
      to_check = to_check.where(template_name: template_names_with_assets)

      logger = Logger.new('log/delete_unreachable.log')
      logger.info("Checking #{to_check.size} contents for unreachable 'content_url' ...")
      puts "Checking #{to_check.size} contents for reachable 'content_url' ..."

      queue = DataCycleCore::WorkerPool.new(ActiveRecord::Base.connection_pool.size - 1)
      faraday = Faraday.default_connection
      deleted_ids = []
      delete_proc = lambda do |thing|
        return print(AmazingPrint::Colors.yellow('x')) if !delete_in_use && thing.content_a.exists?
        deleted_ids << thing.id

        logger.info("Deleting content with id: #{thing.id} and content_url: #{thing.content_url}")
        thing.destroy
        print(AmazingPrint::Colors.red('x'))
      end

      to_check.find_each do |thing|
        queue.append do
          next print('.') if thing.try(:content_url).blank?
          response = faraday.head(thing.content_url)

          if response.status == 404
            delete_proc.call(thing)
          else
            image = FastImage.size(thing.content_url)
            next delete_proc.call(thing) if image.present? && image.is_a?(Array) && image.size == 2 && image.all? { |v| v <= 1 }

            print(AmazingPrint::Colors.green('.'))
          end
        rescue StandardError
          print(AmazingPrint::Colors.yellow('~'))
        end
      end

      queue.wait!

      puts "\nDone (deleted #{deleted_ids.size} contents)."
    end

    desc 'merge contents with same external_system_id and external_key'
    task merge_contents: :environment do |_, args|
      priority_list = Array.wrap(args.extras)
      priority_list.map!(&:to_s)
      priority_list.uniq!
      external_systems = DataCycleCore::ExternalSystem.by_names_identifiers_or_ids(priority_list).to_a
      priority_list.map! { |id| external_systems.find { |es| es.name == id || es.identifier == id || es.id == id } }
      priority_list.compact!
      removed_duplicates = []

      abort('Please provide at least two external_system identifiers') if priority_list.blank? || priority_list.size < 2

      base_query = <<-SQL.squish
        SELECT originals.id AS original_id,
          duplicates.id AS duplicate_id
        FROM things originals
          JOIN external_system_syncs ess ON ess.syncable_id = originals.id
          AND ess.sync_type = 'duplicate'
          LEFT OUTER JOIN things duplicates ON duplicates.external_key = ess.external_key
          AND duplicates.external_source_id = ess.external_system_id
        WHERE originals.external_source_id = :external_system_id
          AND originals.id != duplicates.id
          AND duplicates.external_source_id IN (:duplicate_source_ids)
        UNION
        SELECT originals.id AS original_id,
          duplicates.id AS duplicate_id
        FROM external_system_syncs ess
          JOIN things originals ON ess.syncable_id = originals.id
          JOIN external_system_syncs duplicate_ess ON duplicate_ess.external_key = ess.external_key
          AND duplicate_ess.external_system_id = ess.external_system_id
          AND duplicate_ess.sync_type = 'duplicate'
          JOIN things duplicates ON duplicates.id = duplicate_ess.syncable_id
        WHERE originals.external_source_id = :external_system_id
          AND originals.id != duplicates.id
          AND duplicates.external_source_id IN (:duplicate_source_ids)
          AND ess.sync_type = 'duplicate'
          AND NOT EXISTS (
            SELECT 1
            FROM things
            WHERE things.external_key = ess.external_key
              AND things.external_source_id = ess.external_system_id
          )
          AND NOT EXISTS (
            SELECT 1
            FROM things
            WHERE things.external_key = duplicate_ess.external_key
              AND things.external_source_id = duplicate_ess.external_system_id
          )
        UNION
        SELECT originals.id AS original_id,
          duplicates.id AS duplicate_id
        FROM things originals
          JOIN external_system_syncs ess ON ess.external_key = originals.external_key
          AND ess.external_system_id = originals.external_source_id
          AND ess.sync_type = 'duplicate'
          JOIN things duplicates ON duplicates.id = ess.syncable_id
        WHERE originals.external_source_id = :external_system_id
          AND originals.id != ess.syncable_id
          AND duplicates.external_source_id IN (:duplicate_source_ids);
      SQL

      while priority_list.size > 1
        primary_es = priority_list.shift

        duplicates = ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.send(
            :sanitize_sql_array,
            [
              base_query,
              {
                external_system_id: primary_es.id,
                duplicate_source_ids: priority_list.pluck(:id)
              }
            ]
          )
        ).rows.to_h

        next(puts("-- No duplicates for #{primary_es.name}...")) if duplicates.blank?

        contents = DataCycleCore::Thing.where(id: duplicates.keys + duplicates.values).index_by(&:id)

        puts "Merging duplicates for #{primary_es.name} (#{duplicates.size})..."

        duplicates.each do |original_id, duplicate_id|
          next if removed_duplicates.include?(original_id) || removed_duplicates.include?(duplicate_id)

          original = contents[original_id]
          duplicate = contents[duplicate_id]

          removed_duplicates << duplicate.id
          original.merge_with_duplicate_and_version(duplicate)
        end
      end

      puts '[DONE] finished creating merge jobs.'
    rescue StandardError => e
      puts "Error during merging: #{e.message}"
      raise e
    end
  end
end
