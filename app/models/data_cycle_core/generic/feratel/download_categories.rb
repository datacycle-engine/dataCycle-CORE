module DataCycleCore::Generic::Feratel::DownloadCategories
  def download_content(**options)
    download_data(@source_type,
                  ->(data) { data['Id'] },
                  ->(data) { data['Name'] },
                  options)
  end

  protected

  def endpoint
    @end_point_object.new(credentials.symbolize_keys)
  end
end
