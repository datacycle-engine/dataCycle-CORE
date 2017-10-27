module DataCycleCore::Generic::ImportStrategy::FeratelPlaces
  def import_data(**options)
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
      topics = if raw_data.dig('Details', 'Topics', 'Topic', 'Id')
                 [DataCycleCore::Classification.find_by(external_key: raw_data.dig('Details', 'Topics', 'Topic', 'Id'))]
               else
                 []
               end

      holiday_themes = if raw_data.dig('Details', 'HolidayThemes', 'Item', 'Id')
                         [DataCycleCore::Classification.find_by(external_key: raw_data.dig('Details', 'HolidayThemes', 'Item', 'Id'))]
                       else
                         []
                       end

      create_or_update_content(
        @target_type,
        load_template(@target_type, @data_template),
        extract_place_data(raw_data).with_indifferent_access.merge(
          data_type: nil,
          topics: topics.map(&:id),
          holiday_themes: holiday_themes.map(&:id)
        ).with_indifferent_access
      )
    end
  end

  def extract_place_data(raw_data)
    return {} if raw_data.nil?

    {
      external_key: raw_data['Id'],
      name: raw_data['Details']['Names']['Translation']['text'],
      description: raw_data.dig('Descriptions', 'Description', 'text'),
      street_address: [
        raw_data.dig('Addresses', 'Address').try(:dig, 'AddressLine1', 'text'),
        raw_data.dig('Addresses', 'Address').try(:dig, 'AddressLine2', 'text')
      ].reject(&:blank?).join("\n"),
      address_locality: raw_data.dig('Addresses', 'Address').try(:dig, 'Town', 'text'),
      postal_code: raw_data.dig('Addresses', 'Address').try(:dig, 'ZipCode', 'text'),
      fax_number: raw_data.dig('Addresses', 'Address').try(:dig, 'Fax', 'text'),
      telephone: raw_data.dig('Addresses', 'Address').try(:dig, 'Phone', 'text'),
      email: raw_data.dig('Addresses', 'Address').try(:dig, 'Email', 'text'),
      url: raw_data.dig('Addresses', 'Address').try(:dig, 'URL', 'text')
    }
  end

  def t(*args)
    DataCycleCore::Generic::Transformations::Functions[*args]
  end
end
