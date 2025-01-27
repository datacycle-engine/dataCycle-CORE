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
        return print('x'.yellow) if !delete_in_use && thing.content_a.exists?
        deleted_ids << thing.id

        logger.info("Deleting content with id: #{thing.id} and content_url: #{thing.content_url}")
        thing.destroy
        print('x'.red)
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

            print('.'.green)
          end
        rescue StandardError
          print('~'.yellow)
        end
      end

      queue.wait!

      puts "\nDone (deleted #{deleted_ids.size} contents)."
    end
  end
end
