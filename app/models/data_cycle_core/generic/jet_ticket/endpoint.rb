# frozen_string_literal: true

module DataCycleCore
  module Generic
    module JetTicket
      class Endpoint
        def initialize(host:, end_point:, **options)
          @start_year = 2021
          @future_years = 1

          @host = host
          @end_point = end_point
          @read_type = options[:read_type] if options[:read_type].present?
          @options = options[:options] || {}
        end

        def load_season_data
          raise ArgumentError, 'missing read_type for loading location ranges' if @read_type.nil?

          season_lookup = {}

          DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
            season_lookup = mongo
              .where('dump.de': { '$exists' => true })
              .map { |d| { d.dump.dig('de', 'Name') => d.dump.dig('de') } }
              .inject(&:merge)
          end
          season_lookup
        end

        def events(*)
          season_lookup = load_season_data
          Enumerator.new do |yielder|
            (@start_year..Time.zone.now.year + @future_years).each do |year|
              quarters(year).each do |from, to|
                load_data(service_name: 'EventService', method_name: 'getEvents', xml_generator: 'event_request_xml', path: 'Event', options: { from: from, to: to }).each do |xml_data|
                  data_hash = Hash.from_xml(xml_data.to_xml).dig('Event')
                  data_hash['Season'] = season_lookup[data_hash.dig('Season', 'Name')] if season_lookup[data_hash.dig('Season', 'Name')].present?
                  yielder << data_hash
                end
              end
            end
          end
        end

        def event_sets(*)
          from = '2020-01-01'
          to = "#{Time.zone.now.year + 1}-12-31"
          Enumerator.new do |yielder|
            load_data(service_name: 'EventService', method_name: 'getEventSets', xml_generator: 'event_request_xml', path: 'EventSet', options: { from: from, to: to }).each do |xml_data|
              data_hash = Hash.from_xml(xml_data.to_xml).dig('EventSet')
              yielder << data_hash
            end
          end
        end

        def articles(*)
          item_loader(service_name: 'EventService', method_name: 'getArticles', xml_generator: 'simple_request_xml', path: 'Article')
        end

        def countries(*)
          item_loader(service_name: 'EventService', method_name: 'getCountryList', xml_generator: 'simple_request_xml', path: 'Country')
        end

        def customer_types(*)
          item_loader(service_name: 'EventService', method_name: 'getCustomerTypes', xml_generator: 'simple_request_xml', path: 'CustomerType')
        end

        def event_managers(*)
          item_loader(service_name: 'EventService', method_name: 'getEventManagers', xml_generator: 'simple_request_xml', path: 'EventManager')
        end

        def event_series(*)
          item_loader(service_name: 'EventService', method_name: 'getEventSeriesList', xml_generator: 'simple_request_xml', path: 'EventSeries')
        end

        def event_types(*)
          item_loader(service_name: 'EventService', method_name: 'getEventTypes', xml_generator: 'simple_request_xml', path: 'EventType')
        end

        def regions(*)
          item_loader(service_name: 'EventService', method_name: 'getRegionList', xml_generator: 'simple_request_xml', path: 'Region')
        end

        def seasons(*)
          item_loader(service_name: 'EventService', method_name: 'getSeasons', xml_generator: 'simple_request_xml', path: 'Season')
        end

        def venues(*)
          item_loader(service_name: 'EventService', method_name: 'getVenues', xml_generator: 'simple_request_xml', path: 'Venue')
        end

        def item_loader(service_name:, method_name:, xml_generator:, path:, options: {})
          Enumerator.new do |yielder|
            load_data(service_name: service_name, method_name: method_name, xml_generator: xml_generator, path: path, options: options).each do |xml_data|
              yielder << Hash.from_xml(xml_data.to_xml).dig(path)
            end
          end
        end

        def load_data(service_name:, method_name:, xml_generator:, path:, options:, retry_count: 0)
          url = File.join(@host, @end_point)
          request_parameters = send(xml_generator, service_name, method_name, options)

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          response = Faraday.new.post do |req|
            req.url url
            req.headers['Content-Type'] = 'text/xml'
            req.body = request_parameters
          end

          envelop = Nokogiri::XML(response.body)
          envelop.remove_namespaces!
          data = envelop.xpath('//' + path)
          status = envelop.xpath('//EventServiceResult').children.first&.content
          error = envelop.xpath('//EventService/Error')&.first&.to_hash

          # puts Nokogiri::XML(response.body, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          raise "Error JetTicket - downloading #{service_name}/#{method_name}, Error: #{error}" if status != 'true' || error.present?
          data
        rescue StandardError
          raise if retry_count > 5
          sleep(0)
          load_data(service_name: service_name, method_name: method_name, xml_generator: xml_generator, path: path, options: options, retry_count: retry_count + 1)
        end

        def event_request_xml(service_name, method_name, options)
          add_envelope do |xml|
            create_request_xml(xml, service_name, method_name) do |inner_xml|
              inner_xml.DateFrom(options[:from])
              inner_xml.DateTo(options[:to])
            end
          end
        end

        def simple_request_xml(service_name, method_name, _options)
          add_envelope do |xml|
            create_request_xml(xml, service_name, method_name) do |inner_xml|
            end
          end
        end

        def create_request_xml(xml, service_name, method_name)
          xml.send(service_name, 'xmlns' => 'http://jetticket.datasystems.at/gateway/v6.00') do
            xml.send(service_name) do
              xml.send(method_name) do
                yield(xml)
              end
            end
          end
        end

        def add_envelope
          Nokogiri::XML::Builder.new { |xml|
            xml.send(
              'soap:Envelope',
              'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
              'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
              'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/'
            ) do
              xml.send('Body') do
                yield(xml)
              end
            end
          }.to_xml
        end

        def quarters(year)
          months = [1, 4, 7, 10, 12]
          months[0..-2].zip(months[1..-1]).map do |from, to|
            [
              Time.zone.local(year, from, 1).to_s(:only_date),
              to == 12 ? (Time.zone.local(year + 1, 1, 1) - 1).to_s(:only_date) : (Time.zone.local(year, to, 1) - 1).to_s(:only_date)
            ]
          end
        end
      end
    end
  end
end
