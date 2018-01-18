class DataCycleCore::Generic::OutdoorActive::Endpoint
  def initialize(host: nil, end_point: nil, project: nil, key: nil)
    @host = host
    @end_point = end_point
    @project = project
    @key = key
  end

  def categories(lang: :de)
    Enumerator.new do |yielder|
      process_category = lambda do |category_data|
        yielder << category_data.except('category')

        (category_data['category'] || []).each do |child_category_data|
          process_category.call(child_category_data.merge({ 'parentId' => category_data['id'] }))
        end
      end

      load_data(['category', 'tree'], lang)['category'].each do |category_data|
        process_category.call(category_data)
      end
    end
  end

  def regions(lang: :de)
    Enumerator.new do |yielder|
      process_region = lambda do |region_data|
        yielder << region_data.except('region')

        (region_data['region'] || []).each do |child_region_data|
          process_region.call(child_region_data.merge({ 'parentId' => region_data['id'] }))
        end
      end

      load_data(['region', 'tree'], lang)['region'].each do |region_data|
        process_region.call(region_data)
      end
    end
  end

  def places(lang: :de)
    Enumerator.new do |yielder|
      load_data(['pois'], lang)['data'].each do |poi_id_container|
        yielder << load_data(['oois', poi_id_container['id']], lang)['poi'][0]
      end
    end
  end

  def tours(lang: :de)
    Enumerator.new do |yielder|
      load_data(['tours'], lang)['data'].each do |tour_id_container|
        yielder << load_data(['oois', tour_id_container['id']], lang)['tour'][0]
      end
    end
  end

  protected

  def load_data(url_path, lang = :de)
    response = Faraday.new.get do |req|
      req.url File.join([@host, @end_point, @project] + url_path)

      req.headers['Accept'] = 'application/json'

      req.params['key'] = @key
      req.params['lang'] = lang
      req.params['fallback'] = false
    end

    if response.success?
      JSON.parse(response.body)
    else
      raise DataCycleCore::Generic::RecoverableError, "error loading data from #{File.join([@host, @end_point, @project] + url_path)}"
    end
  end
end
