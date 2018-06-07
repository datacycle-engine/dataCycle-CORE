# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      module Processing
        def process_image(raw_data, config)
          type = config.dig(:content_type).constantize || DataCycleCore::CreativeWork
          template = config.dig(:template) || 'Bild'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::Xamoom::Transformations
              .xamoom_to_image
              .call(raw_data['attributes'])
            ).with_indifferent_access
          )
        end

        def process_spot(raw_data, config)
          type = config.dig(:content_type).constantize || DataCycleCore::Place
          data_template = config.dig(:template) || 'Örtlichkeit'

          create_or_update_content(
            type,
            load_template(type, data_template),
            merge_default_values(
              config,
              DataCycleCore::Generic::Xamoom::Transformations
              .xamoom_to_poi(external_source.id)
              .call(raw_data['attributes'])
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
