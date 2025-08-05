# frozen_string_literal: true

namespace :dc do
  namespace :generate do
    desc 'update all generated translations for collection'
    task :upsert_translations, [:collection_id_or_slug] => [:environment] do |_, args|
      collection_id = args.collection_id_or_slug
      abort('Collection ID or slug is required') if collection_id.blank?

      collection = DataCycleCore::Collection.by_id_name_slug(collection_id).first
      abort("Collection not found for ID or slug: #{collection_id}") if collection.blank?

      things = collection.things
      progressbar = ProgressBar.create(total: things.size, format: '%t |%w>%i| %a - %c/%C', title: collection.name || collection.id)

      things.find_each do |thing|
        thing.try(:upsert_generated_translations)
        progressbar.increment
      end
    end
  end
end
