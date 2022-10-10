# frozen_string_literal: true

module DataCycleCore
  module Export
    module Feratel
      module Transformations
        FERATEL_WDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].freeze

        def self.make_xml(data, utility_object)
          feratel_town =
            data.feratel_locations&.first&.external_key ||
            load_town_hash(utility_object.external_system)[data.content_location&.first&.address&.postal_code]

          return nil, 'no suitable feratel town found' if feratel_town.blank?

          case data.template_name
          when 'Event'
            thing_to_event(data, feratel_town, utility_object.external_system)
          when 'POI'
            # thing_to_infrastructure(data, utility_object.external_system)
            raise DataCycleCore::Export::Common::Error::GenericError "POI not implemented yet. thing(#{data.template_name})!"
          else
            raise DataCycleCore::Export::Common::Error::GenericError "No transformation for given thing(#{data.template_name})!"
          end
        end

        def self.thing_to_event(data, town, external_system)
          config = external_system.credentials(:export)

          location = data.content_location&.first

          return nil, 'no location name found' if location.blank?
          content_location = load_content_location(location)

          feratel_envelope(config) do |xml|
            xml.ImportEvents do
              xml.Event({ 'PartnerId' => data.id, 'PartnerChangeDate' => data.updated_at.to_s(:long_datetime) }) do
                xml.Details do
                  xml.Names do
                    data.available_locales.map do |locale|
                      I18n.with_locale(locale) do
                        xml.Translation(data.title, { 'Language' => locale.to_s })
                      end
                    end
                  end
                  xml.Location do
                    content_location.each do |lang, name|
                      xml.Translation(name, { 'Language' => lang.to_s })
                    end
                  end
                  xml.Active('true')
                  xml.Town(town)
                  if location.longitude.present? && location.longitude.positive? &&
                     location.latitude.present? && location.latitude.positive?
                    xml.Position('Latitude' => location.latitude.to_s, 'Longitude' => location.longitude.to_s)
                  end
                  if data.holiday_themes.present?
                    xml.HolidayThemes do
                      data.hiliday_themes.each do |classification|
                        xml.Item(classification.external_key)
                      end
                    end
                  end
                  # include Visibility(https://fdcwiki.deskline.net/display/CONNECTIVITY/Import+Events Details->Visiblity) default: Region
                  # Enumeration: Local, Town, Region, Subregion, Country
                  xml.Visibility('Country')
                  if data.event_schedule.present?
                    schedules = load_schedules(data)
                    xml.Dates do
                      schedules[:dates].each do |date|
                        xml.Date('From' => date['From'], 'To' => date['To'])
                      end
                    end
                    xml.StartTimes do
                      schedules[:start_times].each do |time|
                        xml.StartTime('Time' => time['Time'], **(time['Days'] || {}))
                      end
                    end
                    xml.Duration(schedules.dig(:duration, 'value'), { 'Type' => schedules.dig(:duration, 'Type') })
                  end
                end
                xml.Addresses do
                  if location.present?
                    xml.Address('Type' => 'Venue') do
                      xml.Company(location.name)
                      xml.Salutation(DataCycleCore::ClassificationAlias.for_tree('Feratel - Salutations').with_name(['unknown', 'Diverse'])&.first&.primary_classification&.external_key)
                      xml.FirstName
                      xml.LastName
                      xml.AddressLine1(location.address.street_address)
                      xml.AddressLine2
                      xml.Country(location.address.address_country)
                      xml.ZipCode(location.address.postal_code)
                      xml.Town(location.address.address_locality)
                      xml.Email(location.contact_info.email)
                      xml.Fax(location.contact_info.fax_number)
                      xml.URL(location.contact_info.url)
                      xml.Phone(location.contact_info.telephone)
                      xml.Mobile
                    end
                  end
                  if data.organizer.first.present?
                    organizer = data.organizer.first
                    xml.Address('Type' => 'Organizer') do
                      xml.Company(organizer.name)
                      xml.Salutation(DataCycleCore::ClassificationAlias.for_tree('Feratel - Salutations').with_name('unknown')&.first&.primary_classification&.external_key)
                      xml.FirstName
                      xml.LastName
                      xml.AddressLine1(organizer.address.street_address)
                      xml.AddressLine2
                      xml.Country(filter_country(organizer.address.address_country))
                      xml.ZipCode(organizer.address.postal_code)
                      xml.Town(organizer.address.address_locality)
                      xml.Email(organizer.contact_info.email)
                      xml.Fax(organizer.contact_info.fax_number)
                      xml.URL(organizer.contact_info.url)
                      xml.Phone(organizer.contact_info.telephone)
                      xml.Mobile
                    end
                  end
                end
                xml.Descriptions do
                  load_event_descriptions(data).each do |descr|
                    xml.Description(descr[:info], { 'Type' => descr[:type], 'Language' => descr[:locale] })
                  end
                end
                xml.Documents do
                  data.image.each do |image|
                    xml.Document({ 'Class' => 'Image', 'Name' => image.name[0..30], 'Extension' => image&.file_type&.first&.name, 'Size' => image&.content_size&.to_i&.to_s, 'Copyright' => image.copyright_notice }) do
                      xml.URL(image.content_url)
                    end
                  end
                end
                xml.Links do
                  data.dc_potential_action&.each do |action|
                    xml.Link({ 'Name' => action.name, 'URL' => action.url })
                  end
                end
              end
            end
          end
        end

        def self.feratel_envelope(config)
          Nokogiri::XML::Builder.new { |xml|
            xml.FeratelDsiRQ('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                             'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                             'xmlns' => 'http://interface.deskline.net/DSI/XSD') do
              xml.Request('Originator' => config['pos_code'], 'Company' => config['company_code']) do
                yield(xml)
              end
            end
          }.to_xml(indent: 2)
        end

        def self.load_town_hash(external_system)
          aggregation = [
            { '$unwind': '$dump.de.Addresses.Address' },
            { '$match': { 'dump.de.Addresses.Address.Type': 'Venue' } },
            { '$match': { 'dump.de.Addresses.Address.ZipCode.text': { '$exists': true } } },
            { '$project': { 'town_id': '$dump.de.Details.Towns.Item.Id', 'zip': '$dump.de.Addresses.Address.ZipCode.text' } },
            { '$group': { '_id': '$zip', 'town': { '$addToSet': '$town_id' } } }
          ]

          external_system
            .query('events') { |i| i.collection.aggregate(aggregation).to_a }
            .map { |i| { i['_id'] => i['town'].first } } # For now: select the first id
            .inject(:merge)
        end

        def self.load_schedules(data)
          return {} if data.event_schedule.blank?

          schedules = { dates: [], start_times: [], duration: nil }

          schedule_data = data
            .event_schedule
            &.map { |s| s.to_hash.merge({ duration: s.duration }) }
            &.map { |s| s.slice(:dtstart, :dtend, :rrules, :duration) }
            &.map { |s|
              s['From'] = s[:dtstart].to_s(:only_date)
              s['To'] = s[:dtend].to_s(:only_date)
              s['Time'] = s[:dtstart].to_s(:only_time)
              s.delete(:dtstart)
              s.delete(:dtend)
              s
            }&.map { |s|
              if s[:rrules]&.first.present?
                rrule = s[:rrules]&.first
                case rrule[:rule_type]
                when 'IceCube::DailyRule'
                  s['Days'] = FERATEL_WDAYS.map { |day| { day => true } }.inject(:merge)
                when 'IceCube::WeeklyRule'
                  days = {}
                  FERATEL_WDAYS.each_with_index { |day, i| days[day] = rrule.dig(:validations, :day).include?(i).to_s }
                  s['Days'] = days
                else
                  raise DataCycleCore::Export::Common::Error::ScheduleFormatError, "Unable to convert Schedule to Feratel format for thing(#{data.id}), schedule: #{s}"
                end
              end
              s.delete(:rrule)
              s
            }
            &.map do |s|
              s['Duration'] = {}
              if s[:duration].blank? || s[:duration]&.zero?
                s['Duration']['value'] = 0
                s['Duration']['Type'] = 'None'
              else
                parts = s[:duration].parts
                [:days, :hours, :minutes].each do |part|
                  if parts[part].present?
                    s['Duration']['value'] = s[:duration].send("in_#{part}")&.to_i&.to_s
                    s['Duration']['Type'] = part.to_s.singularize.capitalize
                  end
                end
              end
              s.delete(:duration)
              s
            end

          if Array.wrap(schedule_data&.select { |i| i['Duration'] }).uniq.size > 1
            # mehr als eine untersch. Dauer --> exception!
            raise DataCycleCore::Export::Common::Error::ScheduleFormatError, "Unable to convert Schedule to Feratel format for thing(#{data.id}), more than one duration detected, schedule: #{data.event_schedule}"
          end

          schedules[:dates] = schedule_data.map { |i| i&.slice('From', 'To') }.uniq
          schedules[:start_times] = schedule_data.map { |i| i&.slice('Time', 'Days') }.uniq
          schedules[:duration] = schedule_data.detect { |i| i['Duration'].present? }&.try(:dig, 'Duration')
          schedules
        end

        def self.load_event_descriptions(data)
          infos = []
          data.available_locales.each do |locale|
            I18n.with_locale(locale) do
              data.additional_information.each do |info|
                type = info.universal_classifications.find_by(name: 'EventHeader')&.name
                type ||= info.universal_classifications.find_by(name: 'EventHeaderShort')&.name
                next if type.blank?
                infos.push({ locale: locale.to_s, type: type, info: info.description })
              end
            end
          end
          if infos.blank?
            type = 'EventHeader'
            data.available_locales.each do |locale|
              next if data.description.blank?
              infos.push({ locale: locale.to_s, type: type, info: data.description })
            end
          end
          infos
        end

        def self.load_content_location(location)
          return nil if location.blank?
          location.available_locales.map { |locale|
            I18n.with_locale(locale) do
              { locale => location&.title }
            end
          }.inject(:merge)
        end

        def self.filter_country(string)
          return if string.blank?
          return unless string.in?(['AT', 'DE', 'IT', 'FR', 'CH', 'NL'])
          string
        end
      end
    end
  end
end
