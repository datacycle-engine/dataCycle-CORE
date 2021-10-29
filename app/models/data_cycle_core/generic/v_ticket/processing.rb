# frozen_string_literal: true

module DataCycleCore
  module Generic
    module VTicket
      module Processing
        def self.process_image(utility_object, raw_data, config)
          template = config&.dig(:template) || 'Bild'

          (raw_data.dig('images') || []).each do |image_hash|
            DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
              utility_object: utility_object,
              template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
              data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
                config,
                DataCycleCore::Generic::VTicket::Transformations
                  .vticket_to_image
                  .call(image_hash)
              ).with_indifferent_access
            )
          end
        end

        def self.process_place(utility_object, raw_data, config)
          return if raw_data&.dig('location').nil?
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data.dig('location'),
            transformation: DataCycleCore::Generic::VTicket::Transformations.vticket_location_to_content_location,
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_event(utility_object, raw_data, config)
          template = config&.dig(:template) || 'Event'

          sub_events = loop_collect(raw_data, 'subEvent') do |item_data|
            transform_sub_event(utility_object, item_data, config&.dig(:embedded, :sub_event), raw_data)
          end

          event_data = DataCycleCore::Generic::VTicket::Transformations
            .vticket_to_event(utility_object.external_source.id)
            .call(raw_data)

          event_data['sub_event'] = sub_events if sub_events.present?

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
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

        def self.transform_sub_event(utility_object, raw_data, config, event_data)
          sub_event = DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
            config,
            DataCycleCore::Generic::VTicket::Transformations
              .vticket_subevent_to_subevent
              .call(raw_data)
          ).with_indifferent_access

          return sub_event if event_data.dig('location', 'id') == raw_data.dig('location', 'id')

          process_place(utility_object, raw_data&.dig('location'), utility_object.external_source.config.dig(:import_config, :events, :transformations, :place))
          DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
            config,
            DataCycleCore::Generic::VTicket::Transformations
              .add_place_to_subevent(utility_object.external_source.id)
              .call(sub_event)
          ).with_indifferent_access
        end
      end
    end
  end
end
