# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ImxPlatform
      class Endpoint
        def initialize(host: nil, end_point: nil, **options)
          @host = host
          @end_point = end_point
          @user_name = options[:user_name]
          @password = options[:password]
          @max_retry = 5
          @params = options.dig(:options, :params) || {}
        end

        def gastro(lang: :de)
          Enumerator.new do |yielder|
            # external_keys = @params[:external_keys]
            changed_from = @params[:changed_from]&.to_date&.to_s(:db) || '2000-01-01'
            ids = load_ids(lang: lang, method: 'FindGastro2Ids', field: 'addressbaseIds', changed_from: changed_from, retry_count: 0).map { |i| i.dig('id') }
            ids.each do |object_id|
              object_data = load_address_details(object_id: object_id, retry_count: 0)
              yielder << object_data if object_data.present?
            end
          end
        end

        def apartment(lang: :de)
          Enumerator.new do |yielder|
            # external_keys = @params[:external_keys]
            changed_from = @params[:changed_from]&.to_date&.to_s(:db) || '2000-01-01'
            ids = load_ids(lang: lang, method: 'FindApartmentIds', field: 'addressbaseIds', changed_from: changed_from, retry_count: 0).map { |i| i.dig('id') }
            ids.each do |object_id|
              object_data = load_address_details(object_id: object_id, retry_count: 0)
              yielder << object_data if object_data.present?
            end
          end
        end

        def poi(lang: :de)
          Enumerator.new do |yielder|
            # external_keys = @params[:external_keys]
            changed_from = @params[:changed_from]&.to_date&.to_s(:db) || '2000-01-01'
            ids = load_ids(lang: lang, method: 'FindAddressPoiIds', field: 'addressPoiIds', changed_from: changed_from, retry_count: 0)
            ids&.map { |i| i.dig('id') }&.each do |object_id|
              object_data = load_address_details(object_id: object_id, retry_count: 0)
              yielder << object_data if object_data.present?
            end
          end
        end

        # def event(lang: :de)
        #   # external_keys = @params[:external_keys]
        #   changed_from = @params[:changed_from]&.to_date&.to_s(:db) || '2000-01-01'
        #   ids = load_ids(lang: lang, method: 'FindEventIds', field: 'addressPoiIds', changed_from: changed_from, retry_count: 0)
        #   ids&.map { |i| i.dig('id') }&.each do |object_id|
        #     object_data = load_address_details(object_id: object_id, retry_count: 0)
        #     yielder << object_data if object_data.present?
        #   end
        # end

        protected

        def load_ids(lang:, method:, field:, changed_from:, retry_count: 0)
          conn = Faraday.new(url: [@host, @end_point].join('/')) do |connection|
            connection.request(:basic_auth, @user_name, @password)
          end
          response = conn.get do |req|
            req.params['method'] = method
            req.params['aLanguage'] = lang.to_s
            req.params['aModifiedFrom'] = changed_from
            req.params['imxFormat'] = 'json'
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}/#{@end_point}?method=#{method}&aLanguage=#{lang}&aModifiedFrom=#{changed_from}&imxFormat=json", response) unless response.success?
          JSON.parse(response.body)[field] || []
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_ids(lang: lang, method: method, field: field, changed_from: changed_from, retry_count: retry_count + 1)
        end

        def load_address_details(object_id:, retry_count: 0)
          method = 'FindAddressbase'
          conn = Faraday.new(url: [@host, @end_point].join('/')) do |connection|
            connection.request(:basic_auth, @user_name, @password)
          end
          response = conn.get do |req|
            req.params['method'] = method
            req.params['objectId'] = object_id
            req.params['imxFormat'] = 'json'
          end

          if response.status == 404 # weird error handling if object_id is not found
            {}
          elsif response.success?
            JSON.parse(response.body)['Addressbase'] || []
          else
            raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}/#{@end_point}?method=#{method}&imxFormat=json", response)
          end
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_ids(object_id: object_id, retry_count: retry_count + 1)
        end
      end
    end
  end
end
