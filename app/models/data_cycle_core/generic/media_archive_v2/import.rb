module DataCycleCore::Generic::MediaArchiveV2::Import
  def import_data(**options)
    @place_template = options[:import][:place_template] || 'Örtlichkeit'
    @person_template = options[:import][:person_template] || 'Person'
    load_transformations
    import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
  end

  def load_transformations
    @image_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_v2_to_bild
    @video_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_v2_to_video
    @content_location_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_v2_to_content_location
    @person_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_person
  end

  protected

  def load_contents(mongo_item, locale)
    mongo_item.where("dump.#{locale}": { '$exists' => true })
  end

  def process_content(raw_data, template, locale)
    I18n.with_locale(locale) do
      content_location = create_or_update_content(
        DataCycleCore::Place,
        load_template(DataCycleCore::Place, @place_template),
        extract_content_location_data(raw_data['contentLocation'])
          .merge({ 'external_key' => "#{raw_data['contentType']}-#{@place_template}: #{raw_data['url'].split('/').last}" }).with_indifferent_access
      )

      director = create_or_update_content(
        DataCycleCore::Person,
        load_template(DataCycleCore::Person, @person_template),
        extract_person_data(raw_data['director'])
          .merge({ 'external_key' => "Regie: #{raw_data['url'].split('/').last}" }).with_indifferent_access
      )

      contributor = create_or_update_content(
        DataCycleCore::Person,
        load_template(DataCycleCore::Person, @person_template),
        extract_person_data(raw_data['contributor'])
          .merge({ 'external_key' => "Kamera: #{raw_data['url'].split('/').last}" }).with_indifferent_access
      )

      raw_data['content_location'] = [{ 'id' => content_location.try(:id) }] unless content_location.blank?
      raw_data['director'] = [{ 'id' => director.try(:id) }] unless director.blank?
      raw_data['contributor'] = [{ 'id' => contributor.try(:id) }] unless contributor.blank?

      case raw_data['contentType']
      when 'Bild'
        data = extract_image_data(raw_data).with_indifferent_access
      when 'Video'
        data = extract_video_data(raw_data).with_indifferent_access
      else
        data = nil
        ap "Unkown contentType #{raw_data}"
      end
      # ap data
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

  def extract_person_data(raw_data)
    raw_data.nil? ? {} : @person_transformation.call(raw_data)
  end
end
