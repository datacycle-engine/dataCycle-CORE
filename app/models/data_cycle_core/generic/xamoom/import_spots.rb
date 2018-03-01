module DataCycleCore
  module Generic
    module Xamoom
      module ImportSpots
        def import_data(**options)
          @image_template = options[:import][:image_template] || 'Bild'
          @tree_label = options.dig(:import, :tree_label) || 'Xamoom - Tags'

          @spot_transformation = DataCycleCore::Generic::Transformations::Transformations.xamoom_to_poi
          @spot_image_transformation = DataCycleCore::Generic::Transformations::Transformations.xamoom_to_image

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.all
        end

        def process_content(raw_data, template, locale)
          I18n.with_locale(locale) do
            unless raw_data.dig('attributes', 'image').blank?
              image = create_or_update_content(
                DataCycleCore::CreativeWork,
                load_template(DataCycleCore::CreativeWork, @image_template),
                extract_image_data(raw_data['attributes']).merge(external_key: "Xamoom - #{raw_data['id']}").with_indifferent_access
              )
            end

            keywords = raw_data.dig('attributes', 'tags') || []
            keywords.each { |item| import_classification({ name: item, external_id: "Xamoom - tag - #{item}", tree_name: @tree_label }) }

            create_or_update_content(
              @target_type,
              load_template(@target_type, @data_template),
              extract_spot_data(raw_data['attributes']).merge(
                data_type: nil,
                image: [image&.id],
                external_key: "Xamoom - #{raw_data['id']}"
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
