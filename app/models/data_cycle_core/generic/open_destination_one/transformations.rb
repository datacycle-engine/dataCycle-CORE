# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_event(external_source_id)
          t(:add_links, 'organizer', DataCycleCore::Thing, external_source_id, ->(s) { [Digest::MD5.hexdigest(DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(s.dig('organiser')).merge('organization' => true).to_s)] })
          .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { [Digest::MD5.hexdigest(DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(s.dig('organiser')).merge('place' => true).to_s)] })
          .>> t(:add_field, 'organizer_key', ->(s) { Digest::MD5.hexdigest(DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(s.dig('organiser')).merge('organization' => true).to_s) })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('id') })
          .>> t(:add_field, 'pimcore_tags', ->(s) { get_tags(s) })
          .>> t(:add_links, 'pimcore_locations', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('locations'))&.map { |name| "Pimcore - Location - #{name}" } || [] })
          .>> t(:add_links, 'pimcore_categories', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('categories'))&.map { |name| "Pimcore - Event-Category - #{name}" } || [] })
          .>> t(:add_field, 'name', ->(s) { s.dig('localizedData', 'name').presence })
          .>> t(:add_field, 'url', ->(s) { s.dig('localizedData', 'bergerlebnisPage').presence || s.dig('localizedData', 'link') })
          .>> t(:add_field, 'potential_action', ->(s) { s.dig('localizedData', 'bookingLink') })
          .>> t(:add_field, 'description', ->(s) { [s.dig('localizedData', 'shortText').presence, s.dig('localizedData', 'longText').presence].compact.join('<br/>') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { get_image_external_keys(s.dig('images')) })
          .>> t(:add_field, 'start_date', ->(s) { get_time(s.dig('localizedData', 'dateInfo', 'dateFrom')) })
          .>> t(:add_field, 'end_date', ->(s) { get_time(s.dig('localizedData', 'dateInfo', 'dateTo')) })
          .>> t(:nest, 'event_period', ['start_date', 'end_date'])
          .>> t(:add_field, 'event_schedule', ->(s) { load_schedules(s.dig('localizedData', 'dateInfo', 'dateItems')) })
          .>> t(:reject_keys, ['id', 'images', 'localizedDate', 'organiser', 'locations', 'categories'])
        end

        def self.opening_hours(data, external_source_id, external_key)
          thing = DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)
          to_update = thing&.opening_hours_specification&.first
          attribute_hash = {}
          attribute_hash['id'] = to_update.id if to_update.present?
          attribute_hash['description'] = data.dig('openingTimes').gsub("\n", '<br/>') if data.dig('openingTimes').present?
          [attribute_hash.presence].compact
        end

        def self.get_tags(hash)
          tags = []
          tags.push('Top Event') if hash.dig('isTopEvent') == true
          tags.push('Berge Plus') if hash.dig('isBergePlus') == true
          tags.push('Empfehlung') if hash.dig('isEmpfehlung') == true
          tags.push('Bergerlebnis') if hash.dig('isBergerlebnis') == true
          tags.map do |tag_name|
            DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Pimcore - Tags', tag_name)
          end
        end

        def self.get_time(input)
          epoc_time = input.is_a?(::String) ? input.squish.to_i : input
          return if epoc_time.blank? || epoc_time < (Time.zone.now - 20.years).to_i
          Time.at(epoc_time).in_time_zone
        end

        def self.weekdays
          ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
        end

        def self.day_nr(day)
          return nil unless weekdays.include?(day)
          Hash[weekdays.zip([1, 2, 3, 4, 5, 6, 0])][day]
        end

        def self.load_schedules(array)
          array.map { |schedule|
            dstart = get_time(schedule.dig('dateFrom'))
            dend = get_time(schedule.dig('dateTo'))
            tstart = schedule.dig('timeFrom').to_datetime
            tend = schedule.dig('timeTo').to_datetime
            dtstart = dstart + tstart.hour * 60 * 60 + tstart.minute * 60
            dtend = dend + tend.hour * 60 * 60 + tend.minute * 60
            duration = tend.to_i - tstart.to_i
            active_days = weekdays
              .select { |day, _val| schedule.dig(day) == '1' }
              .map { |day, _val| day_nr(day) }
              .compact.presence
            rrule = active_days&.size.to_i.in?(1..6) ? IceCube::Rule.weekly : IceCube::Rule.daily
            rrule.hour_of_day(tstart.hour)
            rrule.minute_of_hour(tstart.minute) if tstart.minute.positive?
            rrule.day(active_days) if active_days.present?
            rrule.until(dtend)
            options = {}
            options = { duration: duration } if duration.positive?
            schedule_object = IceCube::Schedule.new(dtstart, options) do |s|
              s.add_recurrence_rule(rrule)
            end
            schedule_object.to_hash.merge(dtstart: dtstart, dtend: dtend).compact
          }.sort_by { |item| item[:dtstart] }
        end
      end
    end
  end
end
