# frozen_string_literal: true

module DataCycleCore
  module Export
    module Feratel
      module Transformations
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
                  # TODO: serialize schedule
                end
                xml.Addresses do
                  if location.present?
                    xml.Address('Type' => 'Venue') do
                      xml.Company(location.name)
                      xml.Salutation(DataCycleCore::ClassificationAlias.for_tree('Feratel - Salutations').with_name('unknown')&.first&.primary_classification&.external_key)
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
                      xml.Country(organizer.address.address_country)
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
                    xml.Document({ 'Class' => 'Image', 'Name' => image.name, 'Extension' => image&.file_type&.first&.name, 'Size' => image&.content_size&.to_i&.to_s }) do
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
      end
    end
  end
end
