module DataCycleCore::Generic::Transformations::Transformations

  def self.t(*args)
    DataCycleCore::Generic::Transformations::Functions[*args]
  end

  def self.media_archive_to_bild
    t(:stringify_keys).
    >> t(:reject_keys, ['@context','@name','@type', 'visibility', 'contentLocation']).
    >> t(:underscore_keys).
    >> t(:tags_to_ids, 'keywords', 'MediaArchive - Tags').
    >> t(:merge, {'data_type' => nil}).
    >> t(:copy_keys, 'url' => 'external_key').
    >> t(:map_value, 'external_key', -> s {s.split('/').last}).
    >> t(:strip_all)
  end

  def self.media_archive_to_content_location
    t(:stringify_keys).
    >> t(:underscore_keys).
    >> t(:unwrap, 'geo', ['longitude', 'latitude']).
    >> t(:rename_keys, 'address' => 'street_address').
    >> t(:map_value, 'name', -> s {s.try:[], I18n.locale.to_s}).
    >> t(:location).
    >> t(:compact).
    >> t(:strip_all)
  end

  def self.eyebase_to_bild
    t(:stringify_keys).
    >> t(:reject_keys, ['quality_256', 'quality_1024', 'picturepins', 'ordnerstruktur']).
    >> t(:unwrap, 'quality_1', ['resolution_x', 'resolution_y', 'size_mb']).
    >> t(:rename_keys, {
      'item_id' => 'external_key',
      'titel' => 'headline',
      'field_202' => 'photographer',
      'copyright' => 'license',
      'field_216' => 'restrictions',
      'resolution_x' => 'width',
      'resolution_y' => 'height',
      'size_mb' => 'content_size'}).
    >> t(:map_value, 'content_size', -> s {(s.try(:gsub, ',', '.').try(:to_f) * 1024 * 1024).to_i}).
    >> t(:map_value, 'width', -> s {s.to_i}).
    >> t(:map_value, 'height', -> s {s.to_i}).
    >> t(:add_field, 'content_url',
      -> s {File.join(ActionMailer::Base.default_url_options[:host], 'eyebase', 'media_assets', 'files',  s['quality_1']['filename']) rescue nil}).
    >> t(:add_field, 'thumbnail_url',
      -> s {File.join(ActionMailer::Base.default_url_options[:host], 'eyebase', 'media_assets', 'files', s['quality_512']['filename']) rescue nil}).
    >> t(:add_field, 'keywords',
      -> s { [s['field_204'].try(:split, ','), s['field_215'].try(:split, ',') ].flatten.reject(&:nil?).map(&:strip).uniq || []}).
    >> t(:tags_to_ids, 'keywords', 'Tags').
    >> t(:reject_keys, ['quality_1', 'quality_512']).
    >> t(:compact).
    >> t(:strip_all)
  end

  def self.eyebase_get_keywords
    t(:add_field, 'keywords',
      -> s { [s['field_204'].try(:split, ','), s['field_215'].try(:split, ',') ].flatten.reject(&:nil?).map(&:strip).uniq || []})
  end

  def self.outdoor_active_to_poi
    t(:stringify_keys).
    >> t(:rename_keys, {
      'id' => 'external_key',
      'title' => 'name',
      'shortText' => 'description',
      'longText' => 'text',
      'altitude' => 'elevation',
      'countryCode' => 'address_country',
      'fax' => 'fax_number',
      'phone' => 'telephone',
      'homepage' => 'url',
      'businessHours' => 'hours_available',
      'fee' => 'price',
      'gettingThere' => 'directions'}).
    >> t(:map_value, 'elevation', -> s {s.to_f}).
    >> t(:add_field, 'latitude', -> s {s['geometry'].try(:split, /[, ]/, 3).try(:[], 1).try(:to_f)}).
    >> t(:add_field, 'longitude', -> s {s['geometry'].try(:split, /[, ]/, 3).try(:[], 0).try(:to_f)}).
    >> t(:location).
    >> t(:add_field, 'address_locality', -> s {s['address'].try(:[], 'town')}).
    >> t(:add_field, 'street_address', -> s {
      unless s['address'].try(:[], 'street').try(:strip).blank?
        [s['address'].try(:[], 'street').try(:strip), s['address'].try(:[], 'housenumber').try(:strip)].join(' ')
      end}).
    >> t(:add_field, 'postal_code', -> s {s['address'].try(:[], 'zipcode')}).
    >> t(:add_field, 'author', -> s {s['meta'].try(:[], 'author')}).
    >> t(:strip_all)
  end

  def self.outdoor_active_to_place
    t(:stringify_keys).
    >> t(:rename_keys, {
      'id' => 'external_key',
      'title' => 'name',
      'shortText' => 'description',
      'longText' => 'text',
      'altitude' => 'elevation',
      'countryCode' => 'address_country',
      'fax' => 'fax_number',
      'phone' => 'telephone',
      'homepage' => 'url',
      'businessHours' => 'hours_available',
      'fee' => 'price',
      'gettingThere' => 'directions'}).
    >> t(:map_value, 'elevation', -> s {s.to_f}).
    >> t(:add_field, 'latitude', -> s {s['geometry'].try(:split, /[, ]/, 3).try(:[], 1).try(:to_f)}).
    >> t(:add_field, 'longitude', -> s {s['geometry'].try(:split, /[, ]/, 3).try(:[], 0).try(:to_f)}).
    >> t(:location).
    >> t(:add_field, 'address_locality', -> s {s['address'].try(:[], 'town')}).
    >> t(:add_field, 'street_address', -> s {
      unless s['address'].try(:[], 'street').try(:strip).blank?
        [s['address'].try(:[], 'street').try(:strip), s['address'].try(:[], 'housenumber').try(:strip)].join(' ')
      end}).
    >> t(:add_field, 'postal_code', -> s {s['address'].try(:[], 'zipcode')}).
    >> t(:add_field, 'author', -> s {s['meta'].try(:[], 'author')}).
    >> t(:strip_all)
  end

  def self.outdoor_active_to_tour
    t(:stringify_keys).
    >> t(:add_field, 'latitude', -> s {s['startingPoint'].try(:[], 'lon').try(:to_f)}).
    >> t(:add_field, 'longitude', -> s {s['startingPoint'].try(:[], 'lat').try(:to_f)}).
    >> t(:add_field, 'start_location', -> s {
        if s['longitude'] && s['latitude']
          RGeo::Geographic.spherical_factory(srid: 4326).point(s['latitude'], s['longitude'])
        else
          nil
        end
        }).
    >> t(:add_field, 'tour', -> s {
        factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
        factory.line_string(
            s['geometry'].try(:split, ' ')
            .try(:map) { |p| p.split(',').map(&:to_f) }
            .try(:map) { |p| factory.point(*p) }
          )
        }).
    >> t(:unwrap, 'elevation', ['ascent', 'descent', 'minAltitude', 'maxAltitude']).
    >> t(:unwrap, 'time', ['min']).
    >> t(:unwrap, 'rating', ['condition', 'difficulty', 'experience', 'landscape']).
    >> t(:add_field, 'author', -> s {s['meta'].try(:[], 'author')}).
    >> t(:rename_keys, {
      'id' => 'external_key',
      'title' => 'name',
      'shortText' => 'description',
      'longText' => 'text',
      'altitude' => 'elevation',
      'minAltitude' => 'min_altitude',
      'maxAltitude' => 'max_altitude',
      'min' => 'duration',
      'condition' => 'condition_rating',
      'difficulty' => 'difficulty_rating',
      'experience' => 'experience_rating',
      'landscape' => 'landscape_rating',
      'directions' => 'instructions',
      'gettingThere' => 'directions',
      'publicTransit' => 'directions_public_transport',
      'safetyGuidelines' => 'safety_instructions',
      'tip' => 'suggestion',
      'additionalInformation' => 'additional_information'
      }).
    >> t(:map_value, 'elevation', -> s {s.to_f}).
    >> t(:map_value, 'length', -> s {s.to_f}).
    >> t(:map_value, 'duration', -> s {s.to_i}).
    >> t(:map_value, 'condition_rating', -> s {s.to_i}).
    >> t(:map_value, 'difficulty_rating', -> s {s.to_i}).
    >> t(:map_value, 'experience_rating', -> s {s.to_i}).
    >> t(:map_value, 'landscape_rating', -> s {s.to_i}).
    >> t(:strip_all)
  end

  def self.outdoor_active_to_image
    t(:stringify_keys).
    >> t(:add_field, 'content_url', -> s {"http://img.oastatic.com/img/#{s['id']}/.jpg"}).
    >> t(:add_field, 'thumbnail_url', -> s {"http://img.oastatic.com/img/400/400/fit/#{s['id']}/.jpg"}).
    >> t(:map_value, 'license', -> s { s.to_s unless s.blank?}).
    >> t(:rename_keys, {
      'id' => 'external_key',
      'title' => 'headline'}).
    >> t(:reject_keys, ['meta', 'primary', 'gallery']).
    >> t(:strip_all)
  end

end
