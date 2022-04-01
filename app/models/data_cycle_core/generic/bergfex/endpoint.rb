# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      class Endpoint
        def initialize(host: nil, end_point: nil, partner: nil, **options)
          @host = host
          @end_point = end_point
          @partner = partner
          @partner_lakes = options.dig(:partner_lakes)
        end

        def lakes(lang: :de)
          Enumerator.new do |yielder|
            load_lake_data.each do |lake|
              yielder << lake
            end
          end
        end

        def snow_resorts(lang: :de)
          Enumerator.new do |yielder|
            load_snow_resort_data(lang: lang).each do |resort|
              yielder << resort
            end
          end
        end

        def snow_reports(lang: :de)
          Enumerator.new do |yielder|
            load_snow_report_data(lang: lang).each do |report|
              yielder << report
            end
          end
        end

        def snow_conditions(lang: :de)
          Enumerator.new do |yielder|
            load_snow_condition_data(lang: lang).each do |condition|
              yielder << condition
            end
          end
        end

        protected

        def load_lake_data
          response = Faraday.new.get do |req|
            req.url(@host + @end_point + 'seen/xml/')
            req.params['partner'] = @partner_lakes || @partner
          end

          # it seems like bergfex returns status 500 for lake data in Winter??
          return [] if response.status == 500

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / partner:#{@partner}", response) unless response.success?
          [Nokogiri::XML(response.body).xpath('//lakes').first.to_hash['lake']].flatten
        end

        def load_snow_resort_data(lang: :de)
          response = Faraday.new.get do |req|
            req.url(@host + @end_point + 'snow/xml/')
            req.params['partner'] = @partner
            req.params['listResorts'] = 1
            req.params['lang'] = lang
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / partner:#{@partner}", response) unless response.success?
          [Nokogiri::XML(response.body).xpath('//resorts').first.to_hash['resort']].flatten
        end

        def load_snow_report_data(lang: :de)
          response = Faraday.new.get do |req|
            req.url(@host + @end_point + 'snow/xml/')
            req.params['partner'] = @partner
            req.params['lang'] = lang
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / partner:#{@partner}", response) unless response.success?
          [Nokogiri::XML(response.body).xpath('//snowreports').first.to_hash['snowreport']].flatten
        end

        def load_snow_condition_data(lang: :de)
          response = Faraday.new.get do |req|
            req.url(@host + @end_point + 'snow/conditions/')
            req.params['lang'] = lang
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / partner:#{@partner}", response) unless response.success?
          [Nokogiri::XML(response.body).xpath('//conditions').first.to_hash['condition']].flatten
        end
      end
    end
  end
end
