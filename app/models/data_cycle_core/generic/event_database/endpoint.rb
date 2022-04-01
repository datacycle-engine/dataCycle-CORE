# frozen_string_literal: true

module DataCycleCore
  module Generic
    module EventDatabase
      class Endpoint
        def initialize(host: nil, end_point: nil, action: nil, **_options)
          @host = host
          @end_point = end_point
          @action = action
          @per = 100
          @max_retry = 10
        end

        def categories(lang: :de)
          Enumerator.new do |yielder|
            next unless lang.to_s == 'de'
            load_data(action: '/categories/tree', retry_count: 0)['categories'].each do |category|
              children = category['children'].collect { |c| c.merge({ 'parentId' => category['id'] }) }
              primary_category = category.without('children').merge({ 'parentId' => nil })

              (children << primary_category).each do |category_item|
                yielder << category_item
              end
            end
          end
        end

        def events(lang: :de)
          first_page = load_data(page: 1, retry_count: 0)
          total_items = first_page['count'].to_i
          max_pages = total_items.fdiv(@per).ceil

          Enumerator.new do |yielder|
            next unless lang.to_s == 'de'
            (1..max_pages).each do |page|
              load_data(page: page, per: @per, lang: lang, retry_count: 0)['events'].each do |event_record|
                yielder << event_record
              end
            end
          end
        end

        protected

        def load_data(page: 1, per: 1, lang: :de, action: @action, retry_count: 0)
          response = Faraday.new.get do |req|
            req.url(@host + @end_point + action)

            req.headers['Accept'] = 'application/json'

            req.params['page'] = page
            req.params['pagesize'] = per
            req.params['filter'] = {
              'from' => (Time.zone.today.at_beginning_of_month - 6.months).to_s('%d.%m.%Y'),
              'to' => (Time.zone.today.at_end_of_month + 5.years).to_s('%d.%m.%Y')
            }
          end

          if !response.success?
            raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point + action} / page:#{page} / per:#{per} / lang:#{lang}", response) if retry_count > 5
            sleep(1)
            load_data(page: page, per: per, lang: lang, retry_count: retry_count + 1)
          else
            JSON.parse(response.body)
          end
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_data(page: page, per: per, lang: lang, retry_count: retry_count + 1)
        end
      end
    end
  end
end
