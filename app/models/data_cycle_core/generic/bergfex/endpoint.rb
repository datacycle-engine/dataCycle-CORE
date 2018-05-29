class DataCycleCore::Generic::Bergfex::Endpoint
  def initialize(host: nil, end_point: nil, partner: nil)
    @host = host
    @end_point = end_point
    @partner = partner
  end

  def lakes(lang: :de)
    Enumerator.new do |yielder|
      load_data.each do |lake|
        yielder << lake
      end
    end
  end

  protected

  def load_data
    response = Faraday.new.get do |req|
      req.url(@host + @end_point)
      req.params['partner'] = @partner
    end

    if response.success?
      data = Nokogiri::XML(response.body).xpath('//lakes').first.to_hash['lake']
    else
      raise DataCycleCore::Generic::RecoverableError, "error loading data from #{@host + @end_point} / partner:#{@partner}" << response.body
    end
  end
end
