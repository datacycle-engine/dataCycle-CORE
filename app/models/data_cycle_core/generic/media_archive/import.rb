module DataCycleCore::Generic::MediaArchive::Import

  def import_data(**options)
    load_transformations
    import_contents(@source_type, @target_type, self.method(:load_contents).to_proc, self.method(:process_content).to_proc, **options)
  end

  def load_transformations
    @image_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_bild
    @content_location_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_content_location
  end

  protected

  def load_contents(mongo_item, locale)
    mongo_item.where("dump.#{locale}.contentType": "Bild")
  end

  def process_content(raw_data, template, locale)
    I18n.with_locale(locale) do
      content_location = create_or_update_content(
        DataCycleCore::Place,
        load_template(DataCycleCore::Place, 'contentLocation'),
        extract_content_location_data(raw_data['contentLocation'])
          .merge({'external_key' => raw_data['url']}).with_indifferent_access
      )

      keywords = raw_data['keywords'] || []
      keywords.each{ |item| import_classification({name: item, external_id: "MedienArchive - keyword - #{item}", tree_name: 'MediaArchive - Tags'}) }

      raw_data.merge!({'content_location' => [{ 'id' => content_location.try(:id) }]}) unless content_location.blank?

      content = create_or_update_content(
        @target_type,
        template,
        extract_image_data(raw_data).with_indifferent_access
      )
    end
  end

  def extract_image_data(raw_data)
    raw_data.nil? ? {} : @image_transformation.call(raw_data)
  end

  def extract_content_location_data(raw_data)
    raw_data.nil? ? {} : @content_location_transformation.call(raw_data)
  end

end
