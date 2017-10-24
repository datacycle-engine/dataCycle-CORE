class DataCycleCore::Generic::DownloadStrategy::EndpointMediaArchive
  def initialize(host: nil, end_point: nil, token: nil)
    @host = host
    @end_point = end_point
    @token = token
    @per = 10
  end

  def image_objects(lang: :de)
    first_page = load_data(1)
    total_items = first_page['count'].to_i
    max_pages = total_items.fdiv(@per).ceil

    Enumerator.new do |yielder|
      (1..max_pages).each do |page|
        load_data(page, @per, lang)['CreativeWorks'].each do |image_record|
          yielder << image_record[lang.to_s]
        end
      end
    end
  end


  protected

  def load_data(page = 1, per = 1, lang = :de)
    response = Faraday.new.get do |req|
      req.url (@host + @end_point)

      req.headers['Accept'] = 'application/json'

      req.params['page'] = page
      req.params['per'] = per
      req.params['token'] = @token
    end

    if response.success?
      JSON.parse(response.body)
    else
      raise DataCycleCore::Import::RecoverableError.new(
        "error loading data from #{@host + @end_point}"
      )
    end
  end
end
