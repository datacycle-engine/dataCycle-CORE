module DataCycleCore
  module Json
    class Import < DataCycleCore::Generic::ImportBase
      def import(**options, &block)
        if options.try(:[], :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new
        else
          @logging = options[:logging_strategy]
        end

        import_images(**options)
      end

      def import_images(**options)
      # import_contents(source_type, target_type, load_contents, process_content, **options)
        import_contents(
          ImageObject,
          DataCycleCore::CreativeWork,
          ->(locale) { ImageObject.where("dump.#{locale}.@type": "schema:ImageObject") },
          ->(raw_data, template, locale) {

            I18n.with_locale(locale) do

              # keywords anlegen (zur Zeit nur als string)

              content_location = create_or_update_content(
                Place,
                load_template(DataCycleCore::Place, 'ContentLocation'),
                extract_content_location_data(raw_data['contentLocation'])
                  .merge({'external_key' => raw_data['url']}).with_indifferent_access
              )

              create_or_update_content(
                CreativeWork,
                load_template(DataCycleCore::CreativeWork, raw_data),
                extract_image_data(raw_data.merge({'content_location' => [{ 'id' => content_location.try(:id) }]})).with_indifferent_access
              )
            end
          },
          **options
        )
      end

      protected

      def extract_image_data(raw_data)
        raw_data.extend(ImageAttributeTransformation).to_h
      end

      def extract_content_location_data(raw_data)
        raw_data.extend(ContentLocationTransformation).to_h
      end

      def create_or_update_content(clazz, template, data)
        content = clazz.find_or_initialize_by(external_source_id: external_source.id,
                                              external_key: data['external_key'])
        content.metadata ||= {}
        content.metadata['validation'] = template.metadata['validation']

        old_data = content.get_data_hash || {}
        content.set_data_hash(old_data.merge(data))

        content.tap(&:save!)
      end

    end
  end
end
