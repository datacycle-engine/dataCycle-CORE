# frozen_string_literal: true

module DataCycleCore
  module Generic
    module EventDatabase
      module Processing
        def process_image(raw_data, config)
          return if raw_data&.dig('image').nil?
          type = config&.dig(:content_type)&.constantize || DataCycleCore::CreativeWork
          template = config&.dig(:template) || 'Bild'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::EventDatabase::Transformations
              .event_database_to_image(raw_data.dig('name'))
              .call(raw_data.dig('image'))
            ).with_indifferent_access
          )
        end

        def process_place(raw_data, config)
          return if raw_data&.dig('location').nil?
          type = config&.dig(:content_type)&.constantize || DataCycleCore::Place
          template = config&.dig(:template) || 'Veranstaltungsort'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::EventDatabase::Transformations
              .event_database_location_to_content_location
              .call(raw_data.dig('location'))
            ).with_indifferent_access
          )
        end

        def process_event(raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::Event
          template = config&.dig(:template) || 'Event'

          sub_event_ids = loop_collect(raw_data, 'subEvents') do |item_data|
            process_sub_event(item_data, config.dig(:embedded, :sub_event))
          end

          event_data = DataCycleCore::Generic::EventDatabase::Transformations
            .event_database_item_to_event(external_source.id)
            .call(raw_data)
          event_data['sub_event'] = sub_event_ids if sub_event_ids.present?

          byebug

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              event_data
            ).with_indifferent_access
          )
        end

        private

        def loop_collect(raw_data, data_name)
          byebug
          return if raw_data&.dig(data_name).nil?
          raw_data&.dig(data_name)&.map do |data|
            id = yield(data)
            id.blank? ? nil : { id: id }
          end
        end

        def process_sub_event(raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::Event
          template = config&.dig(:template) || 'SubEvent'

          process_place(raw_data&.dig('location'), options&.dig(:import, :transformations, :place))

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::EventDatabase::Transformations
              .event_database_sub_item_to_sub_event(external_source.id)
              .call(raw_data)
            ).with_indifferent_access
          )&.id
        end
      end
    end
  end
end
