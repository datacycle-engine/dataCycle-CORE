module DataCycleCore
  module Jsonld
    class Import < DataCycleCore::Import::ImportBase
      def import(**options, &block)
        callbacks = DataCycleCore::Callbacks.new(block)

        import_images(callbacks, **options)
      end

      def import_images(callbacks = DataCycleCore::Callbacks.new, **options)
        # import_contents(source_type, target_type, load_contents, process_content, callbacks, **options)
        import_contents(
          ImageObject,
          DataCycleCore::CreativeWork,
          ->(locale) { ImageObject.where("dump.#{locale}": locale) },
          ->(raw_data, template, locale) {
            I18n.with_locale(locale) do
              images = (raw_data.try(:[], 'images').try(:[], 'image') || []).map { |raw_image_data|
                create_or_update_content(
                  CreativeWork,
                  load_image_template(raw_image_data),
                  extract_image_data(raw_image_data).with_indifferent_access
                )
              }

              categories = [raw_data.dig('category', 'id')].reject(&:blank?).map { |id|
                DataCycleCore::Classification.find_by(external_key: id)
              }.reject(&:nil?)

              regions = raw_data.dig('regions', 'region').map { |r| r['id'] }.reject(&:blank?).map { |id|
                DataCycleCore::Classification.find_by(external_key: id)
              }.reject(&:nil?)

              sources = [raw_data.dig('meta', 'source', 'id')].reject(&:blank?).map { |id|
                DataCycleCore::Classification.find_by(external_key: id)
              }

              create_or_update_content(
                Place,
                template,
                extract_poi_data(raw_data).with_indifferent_access.merge(
                  image: images.map(&:id),
                  categories: categories.map(&:id),
                  regions: regions.map(&:id),
                  source: sources.map(&:id).take(1)
                ).with_indifferent_access
              )
            end
          },
          callbacks,
          **options
        )
      end

    end
  end
end
