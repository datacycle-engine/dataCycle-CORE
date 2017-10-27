module DataCycleCore::Generic::DownloadStrategy::FeratelTypes
  def download_content(**options)
    download_data(@source_type,
                  ->(data) { data['Type'] },
                  ->(data) { [data['Name']['Translation']].flatten.first.try(:[], 'text') },
                  options)
  end

  protected

  def endpoint
    @end_point_object.new(credentials.symbolize_keys)
  end
end
