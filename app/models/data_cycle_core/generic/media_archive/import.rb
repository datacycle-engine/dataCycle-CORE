module DataCycleCore::Generic::MediaArchive::Import
  def import_data(**options)
    load_transformations
    import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
  end

  def load_transformations
    tree_labels = {}
    tree_labels['keywords'] = load_tree_label('keywords') || 'MediaArchive - Tags'
    @image_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_bild(tree_labels)
    @video_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_video(tree_labels)
    @content_location_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_content_location
  end

  def load_tree_label(attribute)
    template = load_template(@target_type, @data_template)
    template.schema.dig('properties', attribute, 'type_name')
  end

  protected

  def load_contents(mongo_item, locale)
    mongo_item.where("dump.#{locale}": { '$exists' => true })
  end

  def process_content(raw_data, template, locale)
    I18n.with_locale(locale) do
      content_location = create_or_update_content(
        DataCycleCore::Place,
        load_template(DataCycleCore::Place, 'contentLocation'),
        extract_content_location_data(raw_data['contentLocation'])
          .merge({ 'external_key' => raw_data['url'] }).with_indifferent_access
      )

      raw_data['content_location'] = [{ 'id' => content_location.try(:id) }] unless content_location.blank?

      case raw_data['contentType']
      when 'Bild'
        data = extract_image_data(raw_data).with_indifferent_access
      when 'Video'
        data = extract_video_data(raw_data).with_indifferent_access
      else
        data = nil
        ap "Unkown contentType #{raw_data}"
      end

      unless data.nil?
        content = create_or_update_content(
          @target_type,
          template,
          data
        )
      end
    end
  end

  def extract_image_data(raw_data)
    raw_data.nil? ? {} : @image_transformation.call(raw_data)
  end

  def extract_video_data(raw_data)
    raw_data.nil? ? {} : @video_transformation.call(raw_data)
  end

  def extract_content_location_data(raw_data)
    raw_data.nil? ? {} : @content_location_transformation.call(raw_data)
  end
end
