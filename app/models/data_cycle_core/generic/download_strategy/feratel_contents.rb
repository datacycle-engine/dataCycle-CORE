module DataCycleCore::Generic::DownloadStrategy::FeratelContents
  def download_content(**options)
    download_data(@source_type,
                  ->(data) { data['Id'] },
                  ->(data) { [data['Details']['Names']['Translation']].flatten.first.try(:[], 'text') },
                  options)
  end

  protected

  def endpoint
    @end_point_object.new(credentials.symbolize_keys)
  end
end
