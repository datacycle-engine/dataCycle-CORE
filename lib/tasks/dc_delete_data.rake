# frozen_string_literal: true

require 'fastimage'

namespace :dc do
  namespace :delete_data do
    desc 'delete all unreachable asset contents from collection'
    task :unreachable, [:template_name_or_collection_id] => [:environment] do |_, args|
      identifier = args.template_name_or_collection_id

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

      puts "Checking #{to_check.size} contents for reachable 'content_url' ..."

      to_check.find_each do |thing|
        next print('.') if thing.try(:content_url).blank?
        check = FastImage.size(thing.content_url)
        next print('.'.green) if check.present? && check.is_a?(Array) && check.all? { |v| v > 1 }

        # binding.pry

        print('x'.red)
      end

      puts "\nDone."
    end
  end
end
