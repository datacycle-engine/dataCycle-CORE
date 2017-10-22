module DataCycleCore::Generic::DownloadStrategy::MediaArchive

  def download_content(**options)
    download_data(@source_type, ->(data) { data['url'] }, ->(data) { data['headline'] }, options)
  end

  protected

  def endpoint
    @endpoint ||= @end_point_object.new(Hash[credentials.map { |k, v| [k.to_sym, v] }])
  end

end
