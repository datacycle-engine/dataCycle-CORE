module DataCycleCore::Generic::OutdoorActive::DownloadCategories
  def download_content(**options)
    download_data(@source_type, ->(data) { data['id'] }, ->(data) { data['name'] }, options)
  end

  protected

  def endpoint
    @end_point_object.new(credentials.symbolize_keys)
  end
end
