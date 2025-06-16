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

      abort('Please provide at least one external_system identifier') if priority_list.blank?

      while priority_list.present?
        primary_es = priority_list.shift

        contents = DataCycleCore::Thing.where(external_source_id: primary_es.id)
        duplicates = DataCycleCore::ExternalSystemSync.includes(:syncable).where(
          external_system_id: primary_es.id, external_key: contents.select(:external_key), sync_type: 'duplicate'
        )
        contents_with_duplicates = contents.where(external_key: duplicates.select(:external_key)).index_by(&:external_key)

        next if duplicates.blank?

        puts "Merging duplicates for #{primary_es.name} (#{duplicates.size})..."

        duplicates.find_each do |es_duplicate|
          next if removed_duplicates.include?(es_duplicate.syncable_id)
          duplicate = es_duplicate.syncable
          original = contents_with_duplicates[es_duplicate.external_key]

          next if original.nil? || original.id == duplicate.id

          removed_duplicates << duplicate.id
          original.merge_with_duplicate_and_version(duplicate)
        end
      end

      puts 'Done.'
    rescue StandardError => e
      puts "Error during merging: #{e.message}"
      raise e
    end
  end
end
