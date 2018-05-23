module DataCycleCore::Generic::EventDatabaseV2::ImportEvents
  def import_data(**options)
    @image_template = options&.dig(:import, :image_template) || 'Bild'
    @place_template = options&.dig(:import, :place_template) || 'Veranstaltungsort'
    load_transformations
    import_contents(
      @source_type,
      @target_type,
      method(:load_contents).to_proc,
      method(:process_content).to_proc,
      **options
    )
  end

  def load_transformations
    @event_transformation = DataCycleCore::Generic::Transformations::Transformations.event_database_item_to_event(external_source.id)
    @sub_event_transformation = DataCycleCore::Generic::Transformations::Transformations.event_database_sub_item_to_sub_event
    @event_location_transformation = DataCycleCore::Generic::Transformations::Transformations.event_database_location_to_content_location
  end

  def load_contents(mongo_item, locale)
    mongo_item.where("dump.#{locale}": { '$exists': true })
  end

  def process_content(raw_data, template, locale)
    I18n.with_locale(locale) do
      image = []

      unless raw_data.dig('image').nil?
        image = create_or_update_content(
          DataCycleCore::CreativeWork,
          load_template(DataCycleCore::CreativeWork, @image_template),
          merge_default_values(:image, extract_event_image_data(raw_data.dig('image'), raw_data['name'])).with_indifferent_access
        )
      end

      unless raw_data.dig('location').nil?
        content_location = create_or_update_content(
          DataCycleCore::Place,
          load_template(DataCycleCore::Place, @place_template),
          merge_default_values(:place, extract_content_location_data(raw_data['location'])).with_indifferent_access
        )
      end

      categories = raw_data.dig('categories').map { |category|
        DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "CATEGORY:#{category.try(:[], 'id')}")
      }.reject(&:nil?)

      sub_events = raw_data.dig('subEvents').nil? ? {} : extract_sub_event_data(raw_data['subEvents'])

      event_data = merge_default_values(:event, extract_event_data(raw_data)).with_indifferent_access

      event_data['location'] = [content_location.try(:id)] if content_location.present?

      event_data['event_category'] = categories.map(&:id) if categories.present?
      event_data['image'] = [image.try(:id)] if image.present?
      event_data['sub_event'] = sub_events if sub_events.present?

      create_or_update_content(
        @target_type,
        template,
        event_data
      )
    end
  end

  def extract_sub_event_data(raw_data)
    raw_data.collect do |sub_event|
      unless sub_event.dig('location').nil?
        content_location = create_or_update_content(
          DataCycleCore::Place,
          load_template(DataCycleCore::Place, @place_template),
          merge_default_values(:place, extract_content_location_data(sub_event['location']))
        )
      end
      item = merge_default_values(:subevent, @sub_event_transformation.call(sub_event))
      item.merge!({ 'location' => [content_location.try(:id)] }) if content_location.present?
    end
  end

  def extract_event_image_data(raw_data, event_name)
    {
      external_key: "IMAGE:#{raw_data.dig('id')}",
      headline: event_name,
      thumbnail_url: raw_data.dig('contentUrl'),
      content_url: raw_data.dig('contentUrl'),
      width: raw_data.dig('width'),
      height: raw_data.dig('height')
    }
  end

  def extract_content_location_data(raw_data)
    raw_data.nil? ? {} : @event_location_transformation.call(raw_data)
  end

  def extract_event_data(raw_data)
    raw_data.nil? ? {} : @event_transformation.call(raw_data)
  end
end
