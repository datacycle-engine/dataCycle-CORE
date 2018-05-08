module DataCycleCore
  module Generic
    module GooglePlaces
      module Import
        def import_data(**options)
          @data_template = options.dig(:import, :data_template) || 'Örtlichkeit'
          @data_type = load_data_type_id(options.dig(:import, :data_type) || 'GooglePlaces')
          @poi_transformation = DataCycleCore::Generic::Transformations::Transformations.google_places_to_poi
          # @source_filter = options.dig(:import, :source_filter) || {}

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, template, locale)
          I18n.with_locale(locale) do
            categories = raw_data.dig('types').map { |name|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "GooglePlaces - Tags - #{name}")
            }.reject(&:nil?)

            ap extract_poi_data(raw_data).merge(data_type: [@data_type], categories: categories.map(&:id))
            byebug

            create_or_update_content(
              @target_type,
              load_template(@target_type, @data_template),
              extract_poi_data(raw_data).merge(
                data_type: [@data_type],
                categories: categories.map(&:id)
              ).with_indifferent_access
            )
          end
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
