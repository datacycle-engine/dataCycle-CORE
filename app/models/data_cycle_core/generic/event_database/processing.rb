# frozen_string_literal: true

module DataCycleCore
  module Generic
    module EventDatabase
      module Processing
        def self.process_image(utility_object, raw_data, config)
          return if raw_data&.dig('image').nil?
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data.dig('image'),
            transformation: DataCycleCore::Generic::EventDatabase::Transformations.event_database_to_image(raw_data.dig('name')),
            default: { content_type: DataCycleCore::CreativeWork, template: 'Bild' },
            config: config
          )
        end

        def self.process_place(utility_object, raw_data, config)
          return if raw_data&.dig('location').nil?
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data.dig('location'),
            transformation: DataCycleCore::Generic::EventDatabase::Transformations.event_database_location_to_content_location,
            default: { content_type: DataCycleCore::Place, template: 'Veranstaltungsort' },
            config: config
          )
        end

        def self.process_event(utility_object, raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::Event
          template = config&.dig(:template) || 'Event'

          sub_event_ids = loop_collect(raw_data, 'subEvents') do |item_data|
            transform_sub_event(utility_object, item_data, config.dig(:embedded, :sub_event))
          end

          event_data = DataCycleCore::Generic::EventDatabase::Transformations
            .event_database_item_to_event(utility_object.external_source.id)
            .call(raw_data)
          event_data['sub_event'] = sub_event_ids if sub_event_ids.present?

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            class_type: type,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template(type, template),
            data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
              config,
              event_data
            ).with_indifferent_access
          )
        end

        def self.loop_collect(raw_data, data_name)
          return if raw_data&.dig(data_name).nil?
          raw_data&.dig(data_name)&.map do |data|
            yield(data).presence
          end
        end

        def self.transform_sub_event(utility_object, raw_data, config)
          process_place(utility_object, raw_data&.dig('location'), utility_object.external_source.config.dig(:import_config, :events, :transformations, :place))

          DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
            config,
            DataCycleCore::Generic::EventDatabase::Transformations
            .event_database_sub_item_to_sub_event(utility_object.external_source.id)
            .call(raw_data)
          ).with_indifferent_access
        end
      end
    end
  end
end