# frozen_string_literal: true

module DataCycleCore
  module Generic
    module VTicket
      class Endpoint
        def initialize(host: nil, end_point: nil, action: nil, token: nil, **_options)
          @host = host
          @end_point = end_point
          @action = action
          @token = token
          @per = 30
        end

        def events(lang: :de)
          first_page = load_data(page: 1)
          total_items = first_page['meta']['total'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            next unless lang == :de
            (1..max_pages).each do |page|
              load_data(page: page, per: @per, lang: lang)['data'].each do |event_record|
                yielder << event_record
              end
            end
          end
        end

        protected

        def load_data(page: 1, per: 1, lang: :de, action: @action)
          conn = Faraday.new(@host)
          conn.authorization :Bearer, @token
          response = conn.get do |req|
            req.url(@host + @end_point + action)

            req.params['page'] = {
              'number' => page,
              'size' => per
            }
            req.params['include'] = 'booking_urls,links,categories,tags,location,location.address,media,promoter,promoter.address'
          end
          raise "error loading data from #{@host + @end_point + action} / page:#{page} / per:#{per} / lang:#{lang}" + response.body unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
