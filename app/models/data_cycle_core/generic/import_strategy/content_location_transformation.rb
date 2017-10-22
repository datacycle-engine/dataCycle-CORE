module DataCycleCore::Generic::ImportStrategy::ContentLocationTransformation

  def name
    self.try(:[], 'name').try(:[], I18n.locale.to_s)
  end

  def longitude
    self.try(:[], 'geo').try(:[], 'longitude')
  end

  def latitude
    self.try(:[], 'geo').try(:[], 'latitude')
  end

  def street_address
    self['address']
  end

  def location
    RGeo::Geographic.spherical_factory(srid: 4326).point(longitude.to_f, latitude.to_f)  unless longitude.blank? || latitude.blank?
  end

  def to_h
    Hash[DataCycleCore::Generic::ImportStrategy::ContentLocationTransformation.public_instance_methods.reject { |m|
      m == :to_h
    }.map { |m|
      [m, send(m)]
    }].reject { |_, v| v.nil? }
  end

end
