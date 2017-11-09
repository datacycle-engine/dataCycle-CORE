module DataCycleCore::Generic::Eyebase::Download
  def download_content(**options)
    download_data(@source_type, ->(data) { data['item_id'] }, ->(data) { data['titel'] }, options)
  end

  protected

  def endpoint
    @end_point_object.new(credentials.symbolize_keys)
  end
end
