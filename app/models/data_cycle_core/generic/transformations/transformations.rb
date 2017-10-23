module DataCycleCore::Generic::Transformations::Transformations

  def self.t(*args)
    DataCycleCore::Generic::Transformations::Functions[*args]
  end

  def self.media_archive_to_bild
    t(:stringify_keys).
    >> t(:reject_keys, ['@context','@name','@type', 'visibility', 'contentLocation']).
    >> t(:underscore_keys).
    >> t(:map_value, 'keywords', -> s {s.try(:join, ' ')}).
    >> t(:copy_keys, 'url' => 'external_key')
  end

  def self.media_archive_to_content_location
    t(:stringify_keys).
    >> t(:underscore_keys).
    >> t(:unwrap, 'geo', ['longitude', 'latitude']).
    >> t(:rename_keys, 'address' => 'street_address').
    >> t(:map_value, 'name', -> s {s.try:[], I18n.locale.to_s}).
    >> t(:location).
    >> t(:compact)
  end

end
