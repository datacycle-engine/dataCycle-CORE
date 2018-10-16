# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module Processing
        def self.process_main_image(utility_object, raw_data, config)
          return if raw_data&.dig('primaryImage').nil?
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data.dig('primaryImage'),
            transformation: DataCycleCore::Generic::OutdoorActive::Transformations.outdoor_active_to_image,
            default: { content_type: DataCycleCore::CreativeWork, template: 'Bild' },
            config: config
          )
        end

        def self.process_image(utility_object, raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::CreativeWork
          template = config&.dig(:template) || 'Bild'

          (raw_data.dig('images', 'image') || []).each do |image_hash|
            DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
              utility_object: utility_object,
              class_type: type,
              template: DataCycleCore::Generic::Common::ImportFunctions.load_template(type, template),
              data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
                config,
                DataCycleCore::Generic::OutdoorActive::Transformations
                .outdoor_active_to_image
                .call(image_hash)
              ).with_indifferent_access
            )
          end
        end

        def self.process_tour(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::OutdoorActive::Transformations.outdoor_active_to_tour(utility_object.external_source.id),
            default: { content_type: DataCycleCore::Thing, template: 'Tour' },
            config: config
          )
        end

        def self.process_place(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::OutdoorActive::Transformations.outdoor_active_to_place(utility_object.external_source.id),
            default: { content_type: DataCycleCore::Thing, template: 'Örtlichkeit' },
            config: config
          )
        end
      end
    end
  end
end
