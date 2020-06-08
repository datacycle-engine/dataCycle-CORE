# frozen_string_literal: true

module DataCycleCore
  module Generic
    module JetTicket
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_event(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('Name1') })
          .>> t(:add_field, 'external_key', ->(s) { 'JetTicket - EventSeriesID: ' + s.dig('EventSetID') })
          .>> t(:add_field, 'event_schedule', ->(s) { Array.wrap(event_schedule(s)) })
          .>> t(:add_field, 'universal_classifications', ->(s) { event_status(s.dig('Status')) })
          .>> t(:strip_all)
        end
        # .>> t(:add_links, 'hrs_dd_categories', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('event', 'category', 'id')]&.compact&.flatten&.map { |item| "HRS DD - Classification: #{s.dig('event', 'classification', 'id')}_#{item}" }&.flatten || [] })
        # .>> t(:add_field, 'event_period', ->(s) { parse_event_period(s.dig('dates'), s.dig('event')) })
        # .>> t(:add_links, 'organizer', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('event', 'contact', 'id')]&.compact&.flatten&.map { |item| "HRS DD - Organizer: #{item}" } })
        # .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('event', 'venue', 'id')]&.compact&.flatten&.map { |item| "HRS DD - Venue: #{item}" } })
        # .>> t(:add_field, 'sub_event', ->(s) { parse_sub_event(s.dig('dates'), s.dig('event')) })
        # .>> t(:event_schedule, ->(s) { s.dig('sub_event') })

        def self.event_schedule(data_hash)
          schedule_hash = {}
          dates = data_hash.dig('dates').map { |d| d&.in_time_zone }.sort
          schedule_hash[:dtstart] = dates.first
          duration = Time.zone.parse(data_hash.dig('Duration')) - Time.new(1900).in_time_zone
          schedule_hash[:dtend] = dates.last + duration
          options = { duration: duration.presence&.to_i }.compact

          schedule_object = IceCube::Schedule.new(schedule_hash[:dtstart].in_time_zone.presence || Time.zone.now, options) do |s|
            dates.each do |rd|
              s.add_recurrence_time(rd)
            end
          end
          schedule_hash[:duration] = duration if duration.present?
          schedule_hash.merge(schedule_object.to_hash)
        end

        def self.event_status(status_string)
          return if status_string.blank?
          bits = status_string.to_i
          return DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('JetTicket - Eventstatus', 'nur Veranstaltungskalender') if bits.zero?
          bit_values = {
            1 => 'im Verkauf',
            2 => 'online',
            4 => 'vorübergehend gestoppt',
            8 => 'ausverkauft',
            16 => 'Event wurde abgesagt'
          }
          bit_values
            .keys
            .select { |v| (bits & v) == v }
            .map { |v| bit_values[v] }
            .map { |v| DataCycleCore::ClassificationAlias.classification_for_tree_with_name('JetTicket - Eventstatus', v)&.id }
            .compact
        end
      end
    end
  end
end
