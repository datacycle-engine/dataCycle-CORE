# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module ImportPois
        def import_data(**options)
          @image_template = options.dig(:import, :image_template) || 'Bild'
          @data_template = options.dig(:import, :data_template) || 'Örtlichkeit'
          @data_type = load_data_type_id(options.dig(:import, :data_type) || 'POI')

          @poi_transformation = DataCycleCore::Generic::Transformations::Transformations.outdoor_active_to_poi
          @poi_image_transformation = DataCycleCore::Generic::Transformations::Transformations.outdoor_active_to_image

          @source_filter = options.dig(:import, :source_filter) || {}

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where(@source_filter) # frontendtype: ["poi", "hut", "lodging", "skiresort", "offerer"]
        end

        def process_content(raw_data, template, locale)
          I18n.with_locale(locale) do
            primary_image = nil
            images = (raw_data.try(:[], 'images').try(:[], 'image') || []).map do |raw_image_data|
              saved_image = create_or_update_content(
                DataCycleCore::CreativeWork,
                load_template(DataCycleCore::CreativeWork, @image_template),
                extract_image_data(raw_image_data).with_indifferent_access
              )
              primary_image = saved_image.id if raw_image_data['primary'] == true
              saved_image.id
            end

            categories = [raw_data.dig('category', 'id')].reject(&:blank?).map { |id|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "CATEGORY:#{id}")
            }.reject(&:nil?)

            regions = (raw_data.dig('regions', 'region') || []).map { |r| r['id'] }.reject(&:blank?).map { |id|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "REGION:#{id}")
            }.reject(&:nil?)

            sources = [raw_data.dig('meta', 'source', 'id')].reject(&:blank?).map do |id|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "SOURCE:#{id}")
            end
            sources_hash = sources.compact.blank? ? [] : sources.map(&:id).take(1)

            create_or_update_content(
              @target_type,
              load_template(@target_type, @data_template),
              extract_poi_data(raw_data).merge(
                data_type: [@data_type],
                primary_image: [primary_image],
                image: images,
                categories: categories.map(&:id),
                regions: regions.map(&:id),
                source: sources_hash
              ).with_indifferent_access
            )
          end
        end

        def extract_image_data(raw_data)
          raw_data.nil? ? {} : @poi_image_transformation.call(raw_data)
        end

        def extract_poi_data(raw_data)
          raw_data.nil? ? {} : @poi_transformation.call(raw_data)
        end

        def load_data_type_id(class_string)
          DataCycleCore::Classification.find_by(name: class_string, external_source_id: nil, external_key: nil)&.id
        end
      end
    end
  end
end
