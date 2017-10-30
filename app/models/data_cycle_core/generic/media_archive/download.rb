module DataCycleCore::Generic::MediaArchive::Download
  def download_content(**options)
    download_data(@source_type, ->(data) { data['url'] }, ->(data) { data['headline'] }, options)
  end

  protected

  def endpoint
    @end_point_object.new(credentials.symbolize_keys)
  end
end
