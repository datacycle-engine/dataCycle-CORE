module DataCycleCore::Generic::Eyebase::Import
  def import_data(**options)
    @eyebase_transformation = DataCycleCore::Generic::Transformations::Transformations.eyebase_to_bild
    @eyebase_get_keywords = DataCycleCore::Generic::Transformations::Transformations.eyebase_get_keywords

    import_contents(@source_type, @target_type, self.method(:load_contents).to_proc, self.method(:process_content).to_proc, **options)
  end

  protected

  def load_contents(mongo_item, locale)
    mongo_item.where("dump.#{locale.to_s}.mediaassettype": '501')
  end

  def process_content(raw_data, template, locale = 'de')
    I18n.with_locale(locale) do
      keywords = extract_keywords(raw_data)
      keywords.each{ |item| import_classification({name: item, external_id: nil, tree_name: 'Tags'}) }

      create_or_update_content(
        @target_type,
        load_template(@target_type, @data_template),
        extract_image_data(raw_data).with_indifferent_access
      )
    end
  end

  def extract_image_data(raw_data)
    raw_data.nil? ? {} : @eyebase_transformation.call(raw_data)
  end

  def extract_keywords(raw_data)
    @eyebase_get_keywords.call(raw_data)['keywords']
  end
end
