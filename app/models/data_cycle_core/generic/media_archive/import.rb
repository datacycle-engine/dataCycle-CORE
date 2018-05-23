module DataCycleCore::Generic::MediaArchive::Import
  def import_data(**options)
    @place_template = options[:import][:place_template] || 'contentLocation'
    load_transformations
    @place_template = options&.dig(:import, :place_template) || 'contentLocation'
    import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
  end

  def load_transformations
    @image_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_bild(external_source.id)
    @video_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_video(external_source.id)
    @content_location_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_content_location
  end

  protected

  def load_contents(mongo_item, locale)
    mongo_item.where("dump.#{locale}": { '$exists' => true })
  end

  def process_content(raw_data, template, locale)
    @place_template ||= DataCycleCore.try(:default_place_type)
    I18n.with_locale(locale) do
      content_location = create_or_update_content(
        DataCycleCore::Place,
        load_template(DataCycleCore::Place, @place_template),
        extract_content_location_data(raw_data['contentLocation'])
          .merge({ 'external_key' => raw_data['url'] }).with_indifferent_access
      )

      raw_data['content_location'] = [{ 'id' => content_location.try(:id) }] if content_location.present?

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
        create_or_update_content(
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
