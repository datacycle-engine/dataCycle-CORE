# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GooglePlaces
      module Processing
        def process_place(raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::Place
          template = config&.dig(:template) || 'Örtlichkeit'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::GooglePlaces::Transformations
              .google_places_to_poi(external_source.id)
              .call(raw_data)
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
