# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module EndpointSearch
        def search_availabilities(*)
          type = :search_availabilities
          xpath = '//Result/ServiceProvider'

          data = load_search_data(type, range_code: @primary_range_code, range_ids: @primary_range_id)
          return data if data.is_a?(::Array) && data.first['error'].present?

          data
            .xpath(xpath)
            .map(&:to_hash)
            .map { |hash_data| { 'id' => hash_data['Id'], 'base_price' => hash_data.dig('Products', 'Product', 'Prices', 'TotalPrice', 'text') } }
        end

        def search_additional_services(*)
          type = :search_additional_services
          xpath = '//Result/ServiceProvider'

          data = load_search_data(type, range_code: @primary_range_code, range_ids: @primary_range_id)
          return data if data.is_a?(::Array) && data.first['error'].present?

          data
            .xpath(xpath).map(&:to_hash)
            .map { |i| i.dig('AdditionalServices', 'Products', 'Product') }
            .flatten
            .group_by { |i| i.dig('ServiceId', 'text') }
            .map { |k, v| { 'id' => k, 'base_price' => v.map { |i| i.dig('Prices', 'BasePrice', 'text')&.to_f }.min.to_s } }
        end

        def load_search_data(type, range_code: 'RG', range_ids: @primary_range_id)
          method_name = "create_#{type}_request_xml"
          url = "#{@endpoint_url}/DSI/Search.asmx/DoSearch"
          request_parameters = send(method_name, range_code: range_code, range_ids: range_ids)

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          faraday = Faraday.new do |f|
            f.request :url_encoded
            f.response :follow_redirects
          end

          response = faraday.post do |req|
            req.url url
            req.body = { 'xmlString' => request_parameters }
          end

          envelop = Nokogiri::XML(response.body)
          data = Nokogiri::XML(envelop.children.first.content)
          data.remove_namespaces!

          # puts Nokogiri::XML(response.body, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          if data.xpath('//@Status').first.value != '0'
            message = data.xpath('//@Message').first.value
            [{ 'error' => message }]
          else
            data
          end
        rescue StandardError
          [{ 'error' => 'Something went wrong.' }]
        end

        def create_search_availabilities_request_xml(range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.SearchLines(
              'StartIndex' => @options.dig(:start_index) || 1,
              'PageSize' => @options.dig(:page_size) || 25,
              'SearchType' => 'OneProductPerHotel',
              'SortOrder' => 'TotalPrice'
            ) do
              @options.dig(:occupation).each_with_index do |line, index|
                parameter_hash = {
                  'Index' => index + 1,
                  'SalesChannel' => @sales_channel_id,
                  'Adults' => line.dig(:adults),
                  'Units' => line.dig(:units),
                  'From' => @options.dig(:from),
                  'To' => @options.dig(:to)
                }
                parameter_hash['MultilineSearchCondition'] = 'And' if index + 1 < @options.dig(:occupation).size
                xml.SearchParameters(parameter_hash) do
                  xml.Children(line.dig(:children)) if line.dig('children').present?
                  xml.BookOnly(1, 'IncludeOnlyOnRequest' => 'true')
                end
              end
            end
          end
        end

        def create_search_additional_services_request_xml(range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.AdditionalServicesSearch(
              'StartIndex' => @options.dig(:start_index) || 1,
              'PageSize' => @options.dig(:page_size) || 25
            ) do
              xml.SearchParameters(
                'Index' => '1',
                'SalesChannel' => @sales_channel_id,
                'Days' => @options.dig(:days) || 1,
                'Units' => @options.dig(:units) || 1,
                'From' => @options.dig(:from),
                'To' => @options.dig(:to)
              ) do
                xml.BookOnly(1, 'IncludeOnlyOnRequest' => 'true')
              end
            end
          end
        end
      end
    end
  end
end
