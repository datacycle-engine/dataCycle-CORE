class DataCycleCore::Generic::EventDatabase::Endpoint
  def initialize(host: nil, end_point: nil, action: nil)
    @host = host
    @end_point = end_point
    @action = action
    @per = 100
  end

  def categories(lang: :de)
    Enumerator.new do |yielder|
      load_data(action: '/categories/tree')['categories'].each do |category|
        children = category['children'].collect { |c| c.merge({ 'parentId' => category['id'] }) }
        primary_category = category.without('children').merge({ 'parentId' => nil })

        (children << primary_category).each do |category_item|
          yielder << category_item
        end
      end
    end
  end

  def events(lang: :de)
    first_page = load_data(page: 1)
    total_items = first_page['count'].to_i
    max_pages = total_items.fdiv(@per).ceil

    Enumerator.new do |yielder|
      (1..max_pages).each do |page|
        load_data(page: page, per: @per, lang: lang)['events'].each do |event_record|
          yielder << event_record
        end
      end
    end
  end

  protected

  def load_data(page: 1, per: 1, lang: :de, action: @action)
    response = Faraday.new.get do |req|
      req.url (@host + @end_point + action)

      req.headers['Accept'] = 'application/json'

      req.params['page'] = page
      req.params['pagesize'] = per
      req.params['filter'] = {
        'from' => Date.today.at_beginning_of_month.to_s(:german_date_format),
        'to' => Date.today.at_end_of_month.next_year.to_s(:german_date_format)
      }
    end

    if response.success?
      JSON.parse(response.body)
    else
      raise DataCycleCore::Generic::RecoverableError.new(
        "error loading data from #{@host + @end_point + action} / page:#{page} / per:#{per} / lang:#{lang}" << response.body
      )
    end
  end
end
