# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      class Endpoint
        def initialize(host: nil, end_point: nil, token: nil, **options)
          @host = host
          @end_point = end_point
          @token = token
          @max_retry = 5
          @per = options[:per] || 25
          @params = options.dig(:options, :params)
        end

        def things(*)
          if @params[:external_keys].present?
            Enumerator.new do |yielder|
              Array.wrap(@params[:external_keys]).each do |key|
                yielder << load_thing(key: key)['@graph'].first
              end
            end
          else
            first_page = load_things(page: 1)
            min_pages = 1
            min_pages = (@params[:min_count] / @per) + 1 if @params[:min_count].present?
            max_pages = (@params[:max_count] / @per) + 1 if @params[:max_count].present?
            max_pages = max_pages.present? ? [max_pages || 1, first_page.dig('meta', 'pages') || 1].min : first_page.dig('meta', 'pages') || 1
            item_pos = [(min_pages - 1) * @per, 1].max - 1
            min_count = @params[:min_count] || 1
            max_count = @params[:max_count] || first_page.dig('meta', 'total')
            Enumerator.new do |yielder|
              (min_pages..max_pages).each do |page|
                load_things(page: page).dig('@graph').each do |data|
                  item_pos += 1
                  next if item_pos < min_count || item_pos > max_count
                  yielder << data
                end
              end
            end
          end
        end

        protected

        def load_things(page: 1, retry_count: 0)
          response = Faraday.new.post do |req|
            req.url File.join([@host, @end_point])
            req.headers['Content-Type'] = 'application/json'
            req.params['token'] = @token
            req.params['page'] = { number: page, size: @per }
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_things(page: page, retry_count: retry_count + 1)
        end

        def load_thing(key: nil, retry_count: 0)
          response = Faraday.new.post do |req|
            req.url File.join([@host, @end_point, key])
            req.headers['Content-Type'] = 'application/json'
            req.params['token'] = @token
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_thing(key: key, retry_count: retry_count + 1)
        end
      end
    end
  end
end
