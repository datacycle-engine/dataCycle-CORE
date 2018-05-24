# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module ImportTours
        def import_data(**options)
          @image_template = options[:import][:image_template] || 'Bild'

          @tour_transformation = DataCycleCore::Generic::Transformations::Transformations.outdoor_active_to_tour
          @tour_image_transformation = DataCycleCore::Generic::Transformations::Transformations.outdoor_active_to_image

          @source_filter = options.dig(:import, :source_filter) || {}

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where(@source_filter.merge("dump.#{locale}.frontendtype" => 'tour'))
        end

        def process_content(raw_data, template, locale)
          I18n.with_locale(locale) do
            images = (raw_data.dig('images', 'image') || []).map do |raw_image_data|
              create_or_update_content(
                DataCycleCore::CreativeWork,
                load_template(DataCycleCore::CreativeWork, @image_template),
                extract_image_data(raw_image_data).with_indifferent_access
              )
            end

            categories = [raw_data.dig('category', 'id')].reject(&:blank?).map { |id|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "CATEGORY:#{id}")
            }.reject(&:nil?)

            tags = (raw_data.dig('properties', 'property') || []).reject(&:blank?).map { |t| t['tag'] }.map { |id|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "TAG:#{id}")
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
              extract_poi_data(raw_data).with_indifferent_access.merge(
                data_type: nil,
                image: images.map(&:id),
                categories: categories.map(&:id),
                outdoor_active_tags: tags.map(&:id),
                regions: regions.map(&:id),
                source: sources_hash
              ).with_indifferent_access
            )
          end
        end

        def extract_image_data(raw_data)
          raw_data.nil? ? {} : @tour_image_transformation.call(raw_data)
        end

        def extract_poi_data(raw_data)
          raw_data.nil? ? {} : @tour_transformation.call(raw_data)
        end
      end
    end
  end
end
