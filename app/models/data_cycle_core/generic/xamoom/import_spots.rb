module DataCycleCore
  module Generic
    module Xamoom
      module ImportSpots
        def import_data(**options)
          @image_template = options[:import][:image_template] || 'Bild'

          @spot_transformation = DataCycleCore::Generic::Transformations::Transformations.xamoom_to_poi(external_source.id)
          @spot_image_transformation = DataCycleCore::Generic::Transformations::Transformations.xamoom_to_image

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.all
        end

        def process_content(raw_data, template, locale)
          I18n.with_locale(locale) do
            image_default_values = {}
            image_default_values = load_default_values(@options.dig(:import, :default_values, :image)) if @options.dig(:import, :default_values, :image).present?
            if raw_data.dig('attributes', 'image').present?
              image = create_or_update_content(
                DataCycleCore::CreativeWork,
                load_template(DataCycleCore::CreativeWork, @image_template),
                image_default_values.merge(extract_image_data(raw_data['attributes']).merge(external_key: "Xamoom - #{raw_data['id']}")).with_indifferent_access
              )
            end

            spot_default_values = {}
            spot_default_values = load_default_values(@options.dig(:import, :default_values, :spot)) if @options.dig(:import, :default_values, :spot).present?
            create_or_update_content(
              @target_type,
              load_template(@target_type, @data_template),
              spot_default_values.merge(
                extract_spot_data(raw_data['attributes']).merge(
                  image: [image&.id],
                  external_key: "Xamoom - #{raw_data['id']}"
                )
              ).with_indifferent_access
            )
          end
        end

        def extract_image_data(raw_data)
          raw_data.nil? ? {} : @spot_image_transformation.call(raw_data)
        end

        def extract_spot_data(raw_data)
          raw_data.nil? ? {} : @spot_transformation.call(raw_data)
        end
      end
    end
  end
end
