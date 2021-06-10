# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module EndpointSearch
        def search_availabilities(*)
          type = :search_availabilities
          xpath = '//Result/ServiceProvider'

          data = load_search_data(type, range_code: @primary_range_code, range_ids: @primary_range_id)
            .xpath(xpath)
            .map(&:to_hash)
            .map { |hash_data| { 'id' => hash_data['Id'], 'base_price' => hash_data.dig('AdditionalServices', 'Products', 'Product', 0, 'Prices', 'BasePrice', 'text') } }
        end

        def search_additional_services(*)
          type = :search_additional_services
          xpath = '//Result/ServiceProvider'

          load_search_data(type, range_code: @primary_range_code, range_ids: @primary_range_id)
            .xpath(xpath).map(&:to_hash)
            .map { |hash_data| hash_data.slice('Id', 'Prices') }
        end

        def load_search_data(type, range_code: 'RG', range_ids: @primary_range_id, retry_count: 0)
          method_name = "create_#{type}_request_xml"
          url = "#{@endpoint_url}/DSI/Search.asmx/DoSearch"
          request_parameters = send(method_name, range_code: range_code, range_ids: range_ids)

          puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          puts
          puts

          response = faraday.post do |req|
            req.url url
            req.body = { 'xmlString' => request_parameters }
          end

          envelop = Nokogiri::XML(response.body)
          data = Nokogiri::XML(envelop.children.first.content)
          data.remove_namespaces!

          puts Nokogiri::XML(response.body, &:noblanks).to_xml(indent: 2)
          puts
          puts

          if data.xpath('//@Status').first.value != '0'
            raise data.xpath('//@Message').first.value if retry_count > 5
            sleep(3)
            load_search_data(type, range_code: range_code, range_ids: range_ids, retry_count: retry_count + 1)
          else
            data
          end
        rescue StandardError
          raise if retry_count > 5
          sleep(3)
          load_search_data(type, range_code: range_code, range_ids: range_ids, retry_count: retry_count + 1)
        end

        def create_search_availabilities_request_xml(range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.SearchLines(
              'StartIndex' => '1',
              'PageSize' => '25',
              'SearchType' => 'OneProductPerHotel',
              'SortOrder' => 'TotalPrice'
            ) do
              xml.SearchParameters(
                'Index' => '1',
                'SalesChannel' => @sales_channel_id,
                'Adults' => @options.dig(:adults),
                'Units' => @options.dig(:units),
                'From' => @options.dig(:from),
                'To' => @options.dig(:to)
              )
            end
          end
        end

        def create_search_additional_services_request_xml(range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.AdditionalServicesSearch(
              'StartIndex' => '1',
              'PageSize' => '25'
            ) do
              xml.SearchParameters(
                'Index' => '1',
                'SalesChannel' => @sales_channel_id,
                'Days' => @options.dig(:days),
                'Units' => @options.dig(:units),
                'From' => @options.dig(:from),
                'To' => @options.dig(:to)
              )
            end
          end
        end
      end
    end
  end
end
