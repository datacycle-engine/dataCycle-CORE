class DataCycleCore::Feratel::Download
  def initialize(uuid)
    @external_source = DataCycleCore::ExternalSource.find(uuid)
    @endpoint = DataCycleCore::Feratel::Endpoint.new(Hash[@external_source.credentials.map { |k, v| [k.to_sym, v] }])
  end

  def download(options = {})
    @endpoint.load_events
  end
end
