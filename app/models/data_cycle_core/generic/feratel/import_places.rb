module DataCycleCore::Generic::Feratel::ImportPlaces
  def import_data(**options)
    @image_template = options[:import][:image_template] || 'Bild'

    import_contents(@source_type,
                    @target_type,
                    method(:load_contents).to_proc,
                    method(:process_content).to_proc,
                    **options)
  end

  protected

  def load_contents(locale)
    @source_type.where("dump.#{locale}" => { '$exists' => true })
  end

  def process_content(raw_data, template, locale)
    I18n.with_locale(locale) do
      images = [raw_data.dig('Documents', 'Document')].flatten.reject(&:nil?).select { |d|
        d['Class'] == 'Image'
      }.map { |raw_image_data|
        create_or_update_content(
          DataCycleCore::CreativeWork,
          load_template(DataCycleCore::CreativeWork, @image_template),
          extract_image_data(raw_image_data).with_indifferent_access
        )
      }

      topics = [raw_data.dig('Details', 'Topics', 'Topic')].flatten.reject(&:nil?).map { |topic|
        DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: topic['Id'])
      }.reject(&:nil?)

      holiday_themes = [raw_data.dig('Details', 'HolidayThemes', 'Item')].flatten.reject(&:nil?).map { |holiday_theme|
        DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: holiday_theme['Id'])
      }.reject(&:nil?)

      facilities = [raw_data.dig('Facilities', 'Facility')].flatten.reject(&:nil?).map { |facility|
        DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: facility['Id'])
      }.reject(&:nil?)

      create_or_update_content(
        @target_type,
        load_template(@target_type, @data_template),
        extract_place_data(raw_data).with_indifferent_access.merge(
          data_type: nil,
          image: images.map(&:id),
          topics: topics.map(&:id),
          holiday_themes: holiday_themes.map(&:id),
          facilities: facilities.map(&:id)
        ).with_indifferent_access
      )
    end
  end

  def extract_image_data(raw_data)
    {
      external_key: raw_data['Id'],
      headline: raw_data.dig('Names', 'Translation', 'text'),
      thumbnail_url: raw_data.dig('URL', 'text'),
      content_url: raw_data.dig('URL', 'text')
    }
  end

  def extract_place_data(raw_data)
    return {} if raw_data.nil?

    short_description = [raw_data.dig('Descriptions', 'Description')].flatten.reject(&:nil?).find { |d|
      d['Type'] == 'InfrastructureShort' || d['Type'] == 'ServiceProviderDescription'
    }
    long_description = [raw_data.dig('Descriptions', 'Description')].flatten.reject(&:nil?).find { |d|
      d['Type'] == 'InfrastructureLong'
    }
    hours_available = [raw_data.dig('Descriptions', 'Description')].flatten.reject(&:nil?).find { |d|
      d['Type'] == 'InfrastructureOpeningTimes'
    }

    address = [raw_data.dig('Addresses', 'Address')].flatten.reject(&:nil?).find { |d|
      d['Type'] == 'InfrastructureExternal' || d['Type'] == 'Object'
    }

    if raw_data.dig('Details', 'Position', 'Latitude').to_i != 0 &&
       raw_data.dig('Details', 'Position', 'Longitude').to_i != 0
      {
        external_key: raw_data['Id'],
        name: raw_data['Details']['Names']['Translation']['text'],
        description: (short_description || {}).dig('text').try(:gsub, /\n/, '<br />'),
        text: (long_description || {}).dig('text').try(:gsub, /\n/, '<br />'),
        hours_available: (hours_available || {}).dig('text').try(:gsub, /\n/, '<br />'),
        street_address: [
          address.try(:dig, 'AddressLine1', 'text'),
          address.try(:dig, 'AddressLine2', 'text')
        ].reject(&:blank?).join("\n"),
        address_locality: address.try(:dig, 'Town', 'text'),
        postal_code: address.try(:dig, 'ZipCode', 'text'),
        fax_number: address.try(:dig, 'Fax', 'text'),
        telephone: address.try(:dig, 'Phone', 'text'),
        email: address.try(:dig, 'Email', 'text'),
        url: address.try(:dig, 'URL', 'text'),
        latitude: raw_data.dig('Details', 'Position', 'Latitude').to_f,
        longitude: raw_data.dig('Details', 'Position', 'Longitude').to_f,
        location: DataCycleCore::Generic::Transformations::Functions.location({
          'latitude' => raw_data.dig('Details', 'Position', 'Latitude').to_f,
          'longitude' => raw_data.dig('Details', 'Position', 'Longitude').to_f,
        })['location']
      }
    else
      {
        external_key: raw_data['Id'],
        name: raw_data['Details']['Names']['Translation']['text'],
        description: (short_description || {}).dig('text').try(:gsub, /\n/, '<br />'),
        text: (long_description || {}).dig('text').try(:gsub, /\n/, '<br />'),
        hours_available: (hours_available || {}).dig('text').try(:gsub, /\n/, '<br />'),
        street_address: [
          address.try(:dig, 'AddressLine1', 'text'),
          address.try(:dig, 'AddressLine2', 'text')
        ].reject(&:blank?).join("\n"),
        address_locality: address.try(:dig, 'Town', 'text'),
        postal_code: address.try(:dig, 'ZipCode', 'text'),
        fax_number: address.try(:dig, 'Fax', 'text'),
        telephone: address.try(:dig, 'Phone', 'text'),
        email: address.try(:dig, 'Email', 'text'),
        url: address.try(:dig, 'URL', 'text')
      }
    end
  end

  def t(*args)
    DataCycleCore::Generic::Transformations::Functions[*args]
  end
end
