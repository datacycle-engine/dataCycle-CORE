module DataCycleCore::OutdoorActive
  class Download < DataCycleCore::Import::DownloadBase
    def download(**options, &block)
      callbacks = DataCycleCore::Callbacks.new(block)

      download_categories(callbacks, **options)
      download_regions(callbacks, **options)
      download_pois(callbacks, **options)
      download_tours(callbacks, **options)
    end

    def download_categories(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(Category, ->(data) { data['id'] }, ->(data) { data['name'] }, callbacks, options)
    end

    def download_regions(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(Region, ->(data) { data['id'] }, ->(data) { data['name'] }, callbacks, options)
    end

    def download_pois(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(Poi, ->(data) { data['id'] }, ->(data) { data['name'] }, callbacks, options)
    end

    def download_tours(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(Tour, ->(data) { data['id'] }, ->(data) { data['name'] }, callbacks, options)
    end


    protected

    def endpoint
      @endpoint ||= Endpoint.new(Hash[credentials.map { |k, v| [k.to_sym, v] }])
    end
  end
end
