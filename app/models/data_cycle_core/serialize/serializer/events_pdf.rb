# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class EventsPdf < Base
        class << self
          def translatable?
            true
          end

          def mime_type
            'application/pdf'
          end

          def serialize_thing(**_options)
            raise 'NOT IMPLEMENTED!'
          end

          def serialize_watch_list(content:, query:, language:, additional_data: {}, **_options)
            content = Array.wrap(content).first
            serialize_collection(content, query || content.things, language, additional_data)
          end

          def serialize_stored_filter(content:, query:, language:, additional_data: {}, **_options)
            serialize_collection(content, query || content.apply.query, language, additional_data)
          end

          private

          def transform_filter(filter)
            return {} if filter.blank?

            {
              fulltext: filter[:q] || filter[:search],
              date: {
                from: filter.dig(:attribute, :schedule, :in, :min)&.in_time_zone || filter.dig(:schedule, :in, :min)&.in_time_zone,
                until: filter.dig(:attribute, :schedule, :in, :max)&.in_time_zone || filter.dig(:schedule, :in, :max)&.in_time_zone
              },
              classifications: DataCycleCore::ClassificationAlias.where(id: filter.dig(:'dc:classification', :in, :withSubtree)).pluck(:internal_name).join(', '),
              location: DataCycleCore::ClassificationAlias.where(id: filter.dig(:linked, :contentLocation, :geo, :in, :shapes)).pluck(:internal_name).join(', ')
            }.deep_reject { |_, v| DataCycleCore::DataHashService.blank?(v) }.with_indifferent_access
          end

          def date_filter_values(content, filter)
            from_dates = []
            to_dates = []
            from, to = DataCycleCore::Filter::Common::Date.date_from_filter_object(filter.dig(:date), 'absolute') if filter.dig(:date).present?
            from_dates.push(from) if from.present?
            to_dates.push(to) if to.present?

            if content.is_a?(DataCycleCore::StoredFilter)
              content.parameters&.each do |param|
                next if param['t'] != 'in_schedule'

                from, to = DataCycleCore::Filter::Common::Date.date_from_filter_object(param['v'], param['q'])

                from_dates.push(from) if from.present?
                to_dates.push(to) if to.present?
              end
            end

            return from_dates.max, to_dates.min
          end

          def serialize_collection(content, query, _language, additional_data)
            filter = transform_filter(additional_data[:filter])
            from_date, to_date = date_filter_values(content, filter)
            title = additional_data[:name].presence || content.name

            query = query.preload(:translations)

            content_locations = DataCycleCore::ContentContent.where(content_a_id: query.map(&:id), relation_a: 'content_location').group_by(&:content_a_id)
            organizers = DataCycleCore::ContentContent.where(content_a_id: query.map(&:id), relation_a: 'organizer').group_by(&:content_a_id)
            related_things = DataCycleCore::Thing.includes(:translations).where(id: content_locations.values.flatten.map(&:content_b_id) + organizers.values.flatten.map(&:content_b_id))
            event_schedules = DataCycleCore::Schedule.where(thing_id: query.map(&:id))
            ActiveRecord::Associations::Preloader.new.preload(query, :classification_aliases, DataCycleCore::ClassificationAlias.for_tree('Veranstaltungskategorien'))
            overlay_templates = DataCycleCore::ThingTemplate.where(template_name: query.map(&:overlay_template_name).uniq + related_things.map(&:overlay_template_name).uniq).index_by(&:template_name)
            related_things.each { |e| e.instance_variable_set(:@overlay_property_names, e.overlay_template_name.present? ? Array.wrap(overlay_templates[e.overlay_template_name]&.property_names) : []) }

            occurences = query.map { |event|
              next unless event.respond_to?(:event_schedule)

              event.set_memoized_attribute('content_location', related_things.select { |e| content_locations[event.id]&.map(&:content_b_id)&.include?(e.id) })
              event.set_memoized_attribute('organizer', related_things.select { |e| organizers[event.id]&.map(&:content_b_id)&.include?(e.id) })
              event.set_memoized_attribute('event_schedule', event_schedules.select { |e| event.id == e.thing_id })
              event.instance_variable_set(:@overlay_property_names, event.overlay_template_name.present? ? Array.wrap(overlay_templates[event.overlay_template_name]&.property_names) : [])

              event
                .event_schedule
                .flat_map(&:to_event_dates)
                .map(&:to_time)
                .compact_blank
                .select { |date| (to_date.blank? || date <= to_date) && (from_date.blank? || date >= from_date) }
                .uniq { |date| date.strftime('%Y-%m-%d') }
                .map { |date| { date:, event: } }
            }.flatten.compact

            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                DataCycleCore::Serialize::SerializedData::Content.new(
                  data: PDFKit.new(
                    DataCycleCore::ApplicationController.renderer.new(
                      http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                      https: Rails.application.config.force_ssl
                    ).render_to_string(
                      formats: [:html],
                      layout: false,
                      locals: { occurences:, endpoint_id: content.id, title:, filter: },
                      template: 'events_pdf/index'
                    ).squish,
                    root_url: Rails.application.config.action_mailer.default_url_options.dig(:host),
                    protocol: Rails.application.config.force_ssl ? 'https' : 'http'
                  ).to_pdf,
                  mime_type:,
                  file_name: file_name(title:),
                  id: content.id
                )
              ]
            )
          end

          def file_name(title:, **_options)
            title&.underscore_blanks.presence || SecureRandom.uuid
          end
        end
      end
    end
  end
end
