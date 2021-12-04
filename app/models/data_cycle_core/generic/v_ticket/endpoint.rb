# frozen_string_literal: true

module DataCycleCore
  module Generic
    module VTicket
      class Endpoint
        def initialize(host: nil, end_point: nil, action: nil, token: nil, filter_selection: nil, **_options)
          @host = host
          @end_point = end_point
          @action = action
          @token = token
          @filter_selection = filter_selection
          @per = 30
          @max_retry = 5
          @conn = Faraday.new(@host)
          @conn.request :authorization, :Bearer, @token
        end

        def events(lang: :de)
          first_page = load_data(page: 1)
          total_items = first_page['meta']['total'].to_i
          max_pages = total_items.fdiv(@per).ceil
          processed_items = []
          Enumerator.new do |yielder|
            next unless lang.to_sym == :de
            (1..max_pages).each do |page|
              load_data(page: page, per: @per, lang: lang)['data'].each do |event_record|
                next if event_record['id'].blank? || processed_items.include?(event_record['id'])
                processed_items << event_record['id']
                event_record['subEvent'] = get_all_event_data(event_record['id'])
                yielder << event_record
              end
            end
          end
        end

        protected

        def get_all_event_data(id)
          first_page = load_data(page: 1, detail_id: id, retry_count: 0)
          total_items = first_page['meta']['total'].to_i
          max_pages = total_items.fdiv(@per).ceil
          result = []
          (1..max_pages).each do |page|
            load_data(page: page, per: @per, detail_id: id, retry_count: 0)['data'].each do |event_detail|
              result << event_detail
            end
          end
          result
        end

        def load_data(page: 1, per: 1, lang: :de, action: @action, detail_id: nil, retry_count: 0)
          response = @conn.get do |req|
            req.url(@host + @end_point + action)

            req.params['page'] = {
              'number' => page,
              'size' => per
            }
            if @filter_selection.present?
              req.params['filter'] = {
                'selection' => @filter_selection
              }
            end
            if detail_id.present?
              req.params['filter'] = {
                'id' => detail_id
              }
            end
            req.params['include'] = 'booking_urls,links,categories,tags,location,location.address,media,promoter,promoter.address'
          end

          if response.success?
            JSON.parse(response.body)
          elsif response.status.to_i == 429 && retry_count <= 5
            sleep(20)
            load_data(page: page, per: per, lang: lang, action: action, detail_id: detail_id, retry_count: (retry_count + 1))
          else
            raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point + action} / page:#{page} / per:#{per} / lang:#{lang}", response)
          end
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_data(page: page, per: per, lang: lang, action: action, detail_id: detail_id, retry_count: (retry_count + 1))
        end
      end
    end
  end
end
