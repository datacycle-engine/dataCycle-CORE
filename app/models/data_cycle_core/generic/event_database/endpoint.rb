class DataCycleCore::Generic::EventDatabase::Endpoint
  def initialize(host: nil, end_point: nil)
    @host = host
    @end_point = end_point
    @per = 100
  end

  # def categories(lang: :de)
  #   first_page = load_data(page: 1)
  #   total_items = first_page['count'].to_i
  #   max_pages = total_items.fdiv(@per).ceil
  #   Enumerator.new do |yielder|
  #     (1..max_pages).each do |page|
  #       load_data(page: page, per: @per, lang: lang)['CreativeWorks'].each do |image_record|
  #         yielder << image_record[lang.to_s]
  #       end
  #     end
  #   end
  # end

  def events(lang: :de)
    first_page = load_data(page: 1, per: @per)
    total_items = first_page['count'].to_i
    max_pages = total_items.fdiv(@per).ceil

    ap first_page
    ap total_items
    ap max_pages

    Enumerator.new do |yielder|
      (1..max_pages).each do |page|
        load_data(page: page, per: @per, lang: lang)['events'].each do |event_record|
          yielder << event_record
        end
      end
    end
  end

  protected

  def load_data(page: 1, per: 1, lang: :de)
    response = Faraday.new.get do |req|
      req.url (@host + @end_point)

      req.headers['Accept'] = 'application/json'

      req.params['page'] = page
      req.params['pagesize'] = per

      ap req
    end
    ap JSON.parse(response.body)
    if response.success?
      JSON.parse(response.body)
    else
      raise DataCycleCore::Generic::RecoverableError.new(
        "error loading data from #{@host + @end_point} / page:#{page} / per:#{per} / lang:#{lang}" << response.body
      )
    end
  end
end
