module DataCycleCore::Generic::ImportStrategy::MediaArchive

  def import_data(**options)
    # import_contents(source_type, target_type, load_contents, process_content, callbacks, **options)
    import_contents(@source_type, @target_type, self.method(:load_contents).to_proc, self.method(:process_content).to_proc, **options)
  end

  protected

  def load_contents(locale)
    @source_type.where("dump.#{locale}.@type": "schema:ImageObject")
  end

  def process_content(raw_data, template, locale)
    I18n.with_locale(locale) do

      #TODO: keywords anlegen (zur Zeit nur als string)

      content_location = create_or_update_content(
        DataCycleCore::Place,
        load_template(DataCycleCore::Place, 'ContentLocation'),
        extract_content_location_data(raw_data['contentLocation'])
          .merge({'external_key' => raw_data['url']}).with_indifferent_access
      )

      raw_data.merge!({'content_location' => [{ 'id' => content_location.try(:id) }]}) unless content_location.blank?

      create_or_update_content(
        @target_type,
        load_template(@target_type, @data_template),
        extract_image_data(raw_data).with_indifferent_access
      )
    end
  end

  def t(*args)
    DataCycleCore::Generic::Transformations::Functions[*args]
  end

  def extract_image_data(raw_data)
    transformation = t(:stringify_keys).
      >> t(:reject_keys, ['@context','@name','@type', 'visibility', 'contentLocation']).
      >> t(:underscore_keys).
      >> t(:map_value, 'keywords', -> s {s.try(:join, ' ')}).
      >> t(:copy_keys, 'url' => 'external_key')

    raw_data.nil? ? {} : transformation.call(raw_data)
  end

  def extract_content_location_data(raw_data)
    transformation = t(:stringify_keys).
     >> t(:underscore_keys).
     >> t(:unwrap, 'geo', ['longitude', 'latitude']).
     >> t(:rename_keys, 'address' => 'street_address').
     >> t(:map_value, 'name', -> s {s.try:[], I18n.locale.to_s}).
     >> t(:location).
     >> t(:compact)

    raw_data.nil? ? {} : transformation.call(raw_data)
  end

  def create_or_update_content(clazz, template, data)
    return nil if data.except('external_key', 'locale').blank?

    content = clazz.find_or_initialize_by(external_source_id: external_source.id,
                                          external_key: data['external_key'])
    content.metadata ||= {}
    content.metadata['validation'] = template.metadata['validation']

    old_data = content.get_data_hash || {}
    content.set_data_hash(old_data.merge(data))

    content.tap(&:save!)
  end

end
