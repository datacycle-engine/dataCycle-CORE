# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module Processing
        def process_image(raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::CreativeWork
          template = config&.dig(:template) || 'Bild'

          (raw_data.dig('images', 'image') || []).each do |image_hash|
            create_or_update_content(
              type,
              load_template(type, template),
              merge_default_values(
                config,
                DataCycleCore::Generic::OutdoorActive::Transformations
                .outdoor_active_to_image
                .call(image_hash)
              ).with_indifferent_access
            )
          end
        end

        def process_tour(raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::Place
          template = config&.dig(:template) || 'Tour'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::OutdoorActive::Transformations
              .outdoor_active_to_tour(external_source.id)
              .call(raw_data)
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
